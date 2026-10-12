# A file's place in its arte (Etapa 1.2, 2/3). Molde, client, referência and
# nome belong to the arte, so they are the same in every file of it: whoever
# changes them on one file (the arte page, a pedido linking the arte, the
# referência read from the file name) changes them on all — and the other
# files then drop a size that isn't the new molde's and look for theirs.
# Part (peca_id), size (tamanho_id) and versions stay per file.
module MembroDeArte
  extend ActiveSupport::Concern

  CAMPOS_DA_ARTE = %w[client_id molde_id modelo_id referencia_id nome].freeze

  included do
    belongs_to :arte, optional: true
    # Before validation, not before_create: the belongs_to autosave runs in
    # before_save, ahead of before_create, so a new Arte set there was never saved.
    before_validation :criar_arte, on: :create
    before_validation :limpar_campos_fora_do_tipo
    validate :sem_molde_fora_do_calcado
    after_update_commit :compartilhar_com_a_arte!, if: -> { arte_id && (saved_changes.keys & CAMPOS_DA_ARTE).any? }
  end

  class_methods do
    # One file per arte — its first — for listings with one card per arte
    # (the gallery). Files without an arte (cortes) are their own.
    # Usage: Arquivo.ativos.where(…).principais_das_artes
    def principais_das_artes
      where(id: unscope(:order, :limit, :offset, :includes).group(Arel.sql("COALESCE(arquivos.arte_id, -arquivos.id)")).select("MIN(arquivos.id)"))
    end
  end

  # The other files of the same arte, trashed ones included.
  # Usage: arquivo.irmaos.ativos
  def irmaos
    return Arquivo.none unless arte_id

    Arquivo.where(arte_id: arte_id).where.not(id: id)
  end

  # The size as shown in the arte's list: the corte's tamanho once known,
  # else what the file name says.
  # Usage: arquivo.rotulo_de_tamanho # => "29-30"
  def rotulo_de_tamanho
    tamanho&.nome || tamanho_rotulo
  end

  # Copies this file's arte fields to the files that differ. Called after an
  # update (callback) and by whoever writes them with update_columns.
  # Usage: arquivo.compartilhar_com_a_arte!
  def compartilhar_com_a_arte!
    valores = attributes.slice(*CAMPOS_DA_ARTE)
    irmaos.to_a.reject { |irmao| irmao.attributes.slice(*CAMPOS_DA_ARTE) == valores }.each { |irmao| irmao.receber_da_arte!(valores) }
  end

  # Usage: irmao.receber_da_arte!("molde_id" => 3, …)
  def receber_da_arte!(valores)
    mudou_molde = molde_id != valores["molde_id"]
    mudou_cliente = client_id != valores["client_id"]
    update_columns(valores)
    return if excluido?

    descartar_tamanho_fora_do_molde!
    buscar_tamanho_em_fila! if mudou_molde
    atualizar_rascunhos_sem_cliente if mudou_cliente
  end

  # Other artes that can be brought into this one (one file each, its
  # first): without a molde or client, or with this arte's —
  # JuntarArtesService refuses moving a file to another molde or client.
  # Usage: arquivo.artes_para_trazer.map { |a| a.arte.titulo }
  def artes_para_trazer
    candidatas = Arquivo.ativos.where(category: "artes").where.not(arte_id: [ arte_id, nil ])
    candidatas.where(molde_id: [ nil, molde_id ].uniq, client_id: [ nil, client_id ].uniq)
              .principais_das_artes.includes(:arte, :referencia, :approved_version, molde: :modelo).order(:filename).limit(100)
  end

  # The same arte uploaded apart in another size: same molde, referência and
  # comparable nome, in another arte — the page offers to join it.
  # Usage: arquivo.mesma_arte_em_outro_envelope.first&.arte&.titulo
  def mesma_arte_em_outro_envelope
    return Arquivo.none unless molde_id && nome.present?

    candidatas = artes_para_trazer.where(molde_id: molde_id, referencia_id: referencia_id).to_a
    Arquivo.where(id: candidatas.select { |outra| TextoComparavel.iguais?(outra.nome, nome) }.map(&:id))
  end

  # Takes this file out of its arte into one of its own (a file grouped by
  # mistake). Its molde, client, referência and nome stay.
  # Usage: arquivo.separar_da_arte!
  def separar_da_arte!
    raise ArgumentError, "#{filename.inspect} is the only file of its arte; expected an arte with two or more files" unless irmaos.ativos.exists?

    update!(arte: Arte.create!(tipo: arte.tipo, no_catalogo: arte.no_catalogo))
  end

  private

  # A work without corte (Etapa 2.5a) has no molde: its sizes are its own.
  def sem_molde_fora_do_calcado
    errors.add(:molde, "can't be set: #{arte.rotulo_do_tipo} is a work without corte") if molde_id && arte && !arte.calcado?
  end

  # Etapa 2.5c: a part read from the file name ("…LATERAL") never sticks to a
  # DTF, nor a size to a corrida or a cor lisa (TipoDaArte#campos_fora_do_tipo).
  def limpar_campos_fora_do_tipo
    assign_attributes(arte.campos_fora_do_tipo) if arte && !arte.calcado?
  end

  def criar_arte
    self.arte ||= Arte.new unless corte?
  end
end
