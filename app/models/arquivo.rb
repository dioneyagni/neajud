class Arquivo < ApplicationRecord
  include Excluivel
  include ReferenciaAtiva

  has_many :arquivo_time_logs, dependent: :destroy
  has_many :arquivo_versions, dependent: :destroy
  has_many :tamanhos, dependent: :destroy
  has_many :arquivo_modelos, dependent: :destroy
  has_many :modelos, through: :arquivo_modelos
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :restrict_with_error
  has_many :item_pedido_pecas, dependent: :restrict_with_error
  has_many :vinculo_logs, -> { order(created_at: :desc) }, class_name: "ArquivoVinculoLog", dependent: :destroy
  belongs_to :approved_version, class_name: "ArquivoVersion", optional: true
  belongs_to :client, optional: true
  belongs_to :molde, optional: true
  belongs_to :peca, optional: true
  belongs_to :modelo, optional: true
  belongs_to :tamanho, optional: true
  has_one :corte, through: :tamanho, source: :arquivo

  before_validation :set_uuid, on: :create
  before_validation :set_default_tipo_corte
  after_update_commit :broadcast_arquivo_card, if: :saved_change_to_approved_version_id?
  before_destroy :prevent_destroy_with_linked_arquivos, prepend: true
  before_destroy :destroy_arquivo_with_versions, prepend: true

  recusa_excluido :client, :modelo, :molde, :peca
  validates :uuid, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :category, inclusion: { in: FileCategory.keys }, allow_nil: true
  validates :tipo_corte, inclusion: { in: %w[apenas_corte corte_estampa] }, if: :corte?
  validate :peca_modelo_uniqueness_for_organized_corte

  SUPPORTED_EXTENSIONS = FileCategory.extensions

  def rotulo_lixeira
    filename
  end

  def corte?
    category == "corte"
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

  def corte_via_modelo
    return nil unless modelo&.molde
    Arquivo.ativos.where(organized: true, molde_id: modelo.molde_id).first
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

  def to_param
    uuid
  end

  def next_version_number
    (arquivo_versions.maximum(:version_number) || 0) + 1
  end

  def approved_original_path
    approved_version&.original_path
  end

  # Organized cortes already claiming `peca_id` for any of `modelo_ids` — the
  # shared query behind conflicting_corte and peca_occupied_for_modelos?, so
  # both stay in sync with what "already taken" means (AGENTS.md: no
  # duplication).
  def self.organized_corte_claiming(peca_id:, modelo_ids:)
    Arquivo.ativos.where(category: "corte", organized: true, peca_id: peca_id)
           .joins(:arquivo_modelos)
           .where(arquivo_modelos: { modelo_id: modelo_ids })
  end

  def self.conflicting_corte(peca_id:, modelo:)
    return nil unless peca_id.present? && modelo.present?
    organized_corte_claiming(peca_id: peca_id, modelo_ids: modelo.id).first
  end

  def peca_occupied_for_modelos?(peca_id: self.peca_id)
    return false unless corte? && peca_id.present?
    modelo_ids = modelos.pluck(:id)
    return false if modelo_ids.empty?
    Arquivo.organized_corte_claiming(peca_id: peca_id, modelo_ids: modelo_ids)
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
    broadcast_replace_to "arquivos", target: ActionView::RecordIdentifier.dom_id(self), partial: "arquivos/card", locals: { arquivo: self }
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

  def peca_modelo_uniqueness_for_organized_corte
    return unless corte? && organized? && peca_id.present?
    return unless peca_occupied_for_modelos?
    errors.add(:peca_id, "já está em uso por outro corte para este modelo")
  end

  def set_default_tipo_corte
    self.tipo_corte ||= "corte_estampa" if corte?
  end

  def broadcast_arquivo_card
    broadcast_replace_to "arquivos", target: ActionView::RecordIdentifier.dom_id(self), partial: "arquivos/card", locals: { arquivo: self }
  end

  def destroy_arquivo_with_versions
    update_columns(approved_version_id: nil, tamanho_id: nil, client_id: nil, modelo_id: nil, molde_id: nil, peca_id: nil)
  end

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
