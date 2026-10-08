class Arquivo < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva
  include NomeDeArte
  include MembroDeArte
  include PapelNaArte
  include LadoNaArte
  include GiroNoEncaixe

  has_many :arquivo_time_logs, dependent: :destroy
  has_many :arquivo_versions, dependent: :destroy
  has_many :tamanhos, dependent: :destroy
  has_many :arquivo_moldes, dependent: :destroy
  has_many :moldes, through: :arquivo_moldes
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :restrict_with_error
  has_many :item_pedido_pecas, dependent: :restrict_with_error
  # The approval records registered from this file's page; the state is the
  # arte's (Aprovavel, Etapa 1.2 2/3).
  has_many :aprovacoes_registradas, class_name: "AprovacaoArte", dependent: :destroy
  has_many :solicitacoes_registradas, class_name: "SolicitacaoAprovacao", dependent: :destroy
  delegate :estado_aprovacao, :rotulo_estado_aprovacao, :aprovacao_vigente, :solicitacao_vigente,
           :alterada_depois_da_aprovacao?, to: :arte, allow_nil: true
  has_many :vinculo_logs, -> { order(created_at: :desc) }, class_name: "ArquivoVinculoLog", dependent: :destroy
  belongs_to :approved_version, class_name: "ArquivoVersion", optional: true
  belongs_to :client, optional: true
  belongs_to :modelo, optional: true
  belongs_to :peca, optional: true
  belongs_to :molde, optional: true
  belongs_to :tamanho, optional: true
  atribui_por_uuid :client, :modelo, :peca, :molde, :tamanho
  has_one :corte, through: :tamanho, source: :arquivo

  before_validation :set_default_tipo_corte
  after_update_commit :broadcast_arquivo_card, if: :saved_change_to_approved_version_id?
  before_destroy :prevent_destroy_with_linked_arquivos, prepend: true
  before_destroy :destroy_arquivo_with_versions, prepend: true

  recusa_excluido :client, :molde, :modelo, :peca
  before_validation :herdar_cliente_do_molde
  validates :tipo_grade, inclusion: { in: GradeDoCorte::TIPOS.keys, message: "%{value} is not a grade type; expected one of par, impar, pmg, furada" }, allow_nil: true
  after_update_commit :atualizar_rascunhos_sem_cliente, if: :saved_change_to_client_id?
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :category, inclusion: { in: FileCategory.keys }, allow_nil: true
  validates :tipo_corte, inclusion: { in: %w[apenas_corte corte_estampa] }, if: :corte?
  validate :peca_molde_uniqueness_for_organized_corte

  SUPPORTED_EXTENSIONS = FileCategory.extensions

  def rotulo_lixeira
    filename
  end

  def corte?
    category == "corte"
  end

  # A queued task marked longer ago than this is stale (the job died): the
  # page stops waiting for it.
  TAREFA_EM_FILA_EXPIRA = 10.minutes

  # TamanhoAutoAssignJob is looking for this arte's tamanho (Etapa 0.6).
  # Usage: <% if arquivo.buscando_tamanho? %>Procurando tamanho…<% end %>
  def buscando_tamanho?
    marca_recente?(buscando_tamanho_desde)
  end

  # PreparacaoTamanhosJob is preparing this corte's tamanhos (Etapa 0.6).
  def preparando_tamanhos?
    marca_recente?(preparando_tamanhos_desde)
  end

  # Queues preparing the tamanhos: re-detect them (after a failed organize or
  # a layer change) or only extract each size's DXF + preview.
  # Usage: corte.preparar_tamanhos_em_fila!(redetectar: corte.organize_error.present?)
  def preparar_tamanhos_em_fila!(redetectar:)
    update_column(:preparando_tamanhos_desde, Time.current)
    PreparacaoTamanhosJob.perform_later(id, redetectar)
  end

  # Queues the automatic tamanho search, unless a tamanho is already set or
  # there is no molde to search in (it was just unlinked).
  # Usage: arte.buscar_tamanho_em_fila!
  def buscar_tamanho_em_fila!
    return if tamanho_id || molde_id.nil?

    update_column(:buscando_tamanho_desde, Time.current)
    TamanhoAutoAssignJob.perform_later(id)
  end

  # Permission área (Autorizacao): cortes (DXF) are Catálogo, the rest Artes.
  # Usage: autorizacao.pode?(arquivo.area_de_acesso, :editar)
  def area_de_acesso
    corte? ? "catalogo" : "artes"
  end

  # Categories a user may list: "corte" needs Catálogo, the rest Artes
  # (nil = not yet classified, shown as an arte).
  # Usage: Arquivo.where(category: Arquivo.categorias_visiveis(autorizacao))
  def self.categorias_visiveis(autorizacao)
    categorias = []
    categorias += [ "artes", nil ] if autorizacao.pode?(:artes, :ver)
    categorias << "corte" if autorizacao.pode?(:catalogo, :ver)
    categorias
  end

  # SQL mirror of #resolved_peca being nil: no peca_id and no corte peça.
  # Usage: Arquivo.where(category: "artes").sem_peca_resolvida
  scope :sem_peca_resolvida, -> {
    joins("LEFT JOIN tamanhos resolved_t ON resolved_t.id = arquivos.tamanho_id")
      .joins("LEFT JOIN arquivos resolved_corte ON resolved_corte.id = resolved_t.arquivo_id")
      .where(arquivos: { peca_id: nil }).where("resolved_corte.peca_id IS NULL")
  }

  # The piece this arte is printed on: the peça of the corte its tamanho
  # belongs to, else the arte's own peca_id (set when an arte is linked to a
  # piece before it has a tamanho). Mirrored in CreateItemPedidoPecas::BACKFILL_SQL.
  # Usage: arte.resolved_peca&.nome # => "Lateral"
  def resolved_peca
    corte&.peca || peca
  end

  # Organized cortes of a molde: the ones linked to it (arquivo_moldes).
  # Several moldes share a modelo, each with its own cortes (e.g. Tenis Baixo
  # → 19-20-25, 21-24, 28-29); taking every corte of the modelo gave an arte of
  # 28-29 the tamanho of 21-24's corte (bug found 28/09/2026). Only when no
  # corte is linked to the molde, the modelo's cortes — of the molde's client
  # only: since the modelos are the official list (Etapa 1.1, 3/5), every
  # client's "Tenis" is the same modelo, and an arte got another client's
  # corte and sizes.
  # Usage: Arquivo.cortes_do_molde(arte.molde)
  def self.cortes_do_molde(molde)
    return none unless molde&.modelo_id

    organizados = ativos.where(organized: true)
    ligados = organizados.joins(:arquivo_moldes).where(arquivo_moldes: { molde_id: molde.id })
    ligados.exists? ? ligados : organizados.where(modelo_id: molde.modelo_id, client_id: molde.client_id)
  end

  # The client page (01/10/2026) shows each corte once: under a molde the
  # organized cortes linked to it; everything else of the client — not
  # organized yet, or organized but linked to no active molde — waits in
  # "Cortes não organizados".
  # Usage: Arquivo.cortes_ligados_ao_molde(molde)
  def self.cortes_ligados_ao_molde(molde)
    ativos.where(category: "corte", organized: true).joins(:arquivo_moldes).where(arquivo_moldes: { molde_id: molde.id })
  end

  # Usage: Arquivo.cortes_pendentes_do_cliente(client)
  def self.cortes_pendentes_do_cliente(client)
    do_cliente = ativos.where(category: "corte", client_id: client.id)
    ligados = ArquivoMolde.joins(:molde).merge(Molde.ativos).select(:arquivo_id)
    do_cliente.where(organized: false).or(do_cliente.where.not(id: ligados))
  end

  # This arte's corte through its molde: the one of its own peça when it has
  # one, else the first of the molde's cortes.
  def corte_via_molde
    cortes = Arquivo.cortes_do_molde(molde).order(:id).to_a
    (peca_id && cortes.find { |corte| corte.peca_id == peca_id }) || cortes.first
  end

  # After an arte's molde changes or is unlinked: a tamanho from a corte that
  # isn't the new molde's is dropped — the auto search never overrides a
  # tamanho, so the old molde's size used to stay (28/09/2026).
  # Usage: arte.descartar_tamanho_fora_do_molde!
  def descartar_tamanho_fora_do_molde!
    return if corte? || tamanho.nil?
    return if molde && Arquivo.cortes_do_molde(molde).exists?(id: tamanho.arquivo_id)

    update_column(:tamanho_id, nil)
  end

  # Like corte_via_molde, but nil when it would be a guess: the molde has
  # several cortes (lateral, língua…) and the arte has no peça to pick one.
  def corte_inequivoco_via_molde
    cortes = Arquivo.cortes_do_molde(molde).order(:id).to_a
    return cortes.first if cortes.one?

    peca_id && cortes.find { |corte| corte.peca_id == peca_id }
  end

  def artes_vinculadas
    return Arquivo.none unless corte? && tipo_corte == "corte_estampa"
    Arquivo.ativos.where(category: "artes", tamanho_id: tamanhos.pluck(:id))
  end

  delegate :preview_file, :category_notes,
           to: :approved_version, allow_nil: true, prefix: false

  %i[colorspace colorspace_error has_spots icc_profile width_px height_px dpi metadata].each do |attr|
    define_method(attr) do
      approved_version&.image_metadata&.public_send(attr)
    end
  end

  def has_spots?
    has_spots
  end

  def detected_program
    metadata&.dig("source_program")
  end

  def program_icon
    FileCategory.program_icon(extension, detected_program: detected_program)
  end

  STATUS_VALUES = %w[pending processing processed failed invalid_colorspace unsupported_format].freeze

  def self.statuses
    STATUS_VALUES.index_with(&:itself)
  end

  def status
    approved_version&.status
  end

  STATUS_VALUES.each do |name|
    define_method("#{name}?") do
      status == name
    end
  end

  # 01/10/2026 (pedido ed6a2aba): an arte linked to a client's molde belongs
  # to that client — linking it from a pedido already did it, the arte page didn't.
  def herdar_cliente_do_molde
    self.client = molde.client if category == "artes" && client_id.nil? && molde && will_save_change_to_molde_id?
  end
  private :herdar_cliente_do_molde

  # A draft pedido waiting for its artes' client adopts it (Pedido#adotar_cliente_das_artes!).
  def atualizar_rascunhos_sem_cliente
    Pedido.ativos.rascunhos.where(client_id: nil).joins(:itens_pedido).where(itens_pedido: { arquivo_id: id }).distinct.each(&:adotar_cliente_das_artes!)
  end
  private :atualizar_rascunhos_sem_cliente

  def next_version_number
    (arquivo_versions.maximum(:version_number) || 0) + 1
  end

  # A new version, put in use and queued for processing. The block writes the
  # original file (the version's storage dir is known before saving) and may
  # refuse by returning false — then nothing is saved.
  # Usage: arquivo.nova_versao!(nome_original: "19-x.tif", mime_type: "image/tiff") { |v| v.store_original!(upload) }
  def nova_versao!(nome_original:, mime_type:)
    versao = arquivo_versions.build(
      version_number: next_version_number, filename: File.basename(nome_original, ".*"),
      extension: File.extname(nome_original).delete(".").downcase, mime_type: mime_type,
      status: :pending, category: category, original_file: nome_original
    )
    return nil if yield(versao) == false

    usar_versao!(versao)
    ArquivoProcessingJob.perform_later(versao.id)
    versao
  end

  def usar_versao!(versao)
    transaction do
      versao.save!
      arquivo_versions.where(approved: true).where.not(id: versao.id).update_all(approved: false)
      versao.update!(approved: true)
      update!(approved_version_id: versao.id)
    end
  end
  private :usar_versao!

  def approved_original_path
    approved_version&.original_path
  end

  # Organized cortes already claiming `peca_id` for any of `molde_ids` — the
  # shared query behind conflicting_corte and peca_occupied_for_moldes?, so
  # both stay in sync with what "already taken" means (AGENTS.md: no
  # duplication).
  def self.organized_corte_claiming(peca_id:, molde_ids:)
    Arquivo.ativos.where(category: "corte", organized: true, peca_id: peca_id)
           .joins(:arquivo_moldes)
           .where(arquivo_moldes: { molde_id: molde_ids })
  end

  def self.conflicting_corte(peca_id:, molde:)
    return nil unless peca_id.present? && molde.present?
    organized_corte_claiming(peca_id: peca_id, molde_ids: molde.id).first
  end

  def peca_occupied_for_moldes?(peca_id: self.peca_id)
    return false unless corte? && peca_id.present?
    molde_ids = moldes.pluck(:id)
    return false if molde_ids.empty?
    Arquivo.organized_corte_claiming(peca_id: peca_id, molde_ids: molde_ids)
           .where.not(id: id)
           .exists?
  end

  # Each page reacts only to what it shows, so a refresh never wipes what the
  # user is doing elsewhere (files picked for the next upload, a typed grade):
  # the gallery swaps just this card on every status change; this arquivo's
  # page and the pedidos that use it morph-refresh only when processing ends.
  # Broadcast right away (not *_later): this runs inside the processing job,
  # and queued broadcasts arrived out of order — a late refresh landed after
  # the user had already opened the page and reset an open editor.
  # Usage: arquivo.broadcast_status_change
  def broadcast_status_change
    broadcast_arquivo_card
    return if pending? || processing?

    broadcast_refresh
    pedidos_que_usam.each(&:broadcast_refresh)
  end

  # Pedidos with an item for this arte, or with it as one of an item's pieces.
  def pedidos_que_usam
    item_ids = ItemPedidoPeca.where(arquivo_id: id).select(:item_pedido_id)
    Pedido.where(id: ItemPedido.where(arquivo_id: id).or(ItemPedido.where(id: item_ids)).select(:pedido_id))
  end

  private

  # Bug (found while verifying feat/mold-org-cascade-filter, PR #70):
  # destroying a corte cascades to destroy its Tamanhos (has_many :tamanhos,
  # dependent: :destroy above), but arquivos.tamanho_id has a real DB-level
  # foreign key (db/schema.rb: add_foreign_key "arquivos", "tamanhos") — an
  # arte still linked to one of those Tamanhos via tamanho_id makes SQLite
  # reject the DELETE. Unguarded, that raised an unhandled
  # SQLite3::ConstraintException -> unlogged 500 (config/environments/*.rb
  # sets show_exceptions: :rescuable, which doesn't log unrescuable errors).
  # This turns it into a normal validation-style rejection instead.
  def prevent_destroy_with_linked_arquivos
    linked = linked_arquivos_via_tamanhos
    return if linked.none?
    errors.add(:base, "não pode ser excluído: #{linked.count} arquivo(s) ainda vinculado(s) a um tamanho deste corte (#{linked.pluck(:filename).to_sentence})")
    throw :abort
  end

  def linked_arquivos_via_tamanhos
    Arquivo.where(tamanho_id: tamanhos.pluck(:id)).where.not(id: id)
  end

  def peca_molde_uniqueness_for_organized_corte
    return unless corte? && organized? && peca_id.present?
    return unless peca_occupied_for_moldes?
    errors.add(:peca_id, "já está em uso por outro corte para este molde")
  end

  def set_default_tipo_corte
    self.tipo_corte ||= "corte_estampa" if corte?
  end

  # The gallery shows one card per arte, its first file's (Etapa 1.2, 2/3):
  # a change in any file of the arte redraws that card.
  def broadcast_arquivo_card
    cartao = arte&.principal || self
    broadcast_replace_to "arquivos", target: ActionView::RecordIdentifier.dom_id(cartao), partial: "arquivos/card", locals: { arquivo: cartao }
  end

  def destroy_arquivo_with_versions
    update_columns(approved_version_id: nil, tamanho_id: nil, client_id: nil, molde_id: nil, modelo_id: nil, peca_id: nil)
  end

  def marca_recente?(momento)
    momento.present? && momento > TAREFA_EM_FILA_EXPIRA.ago
  end
end
