# What kind of work an arte is (Etapa 2.5a, decided 12/10/2026): calçado —
# molde, parts and sizes by the corte, everything until now — or a work
# without corte: etiqueta DTF, estampa corrida, cor lisa. A DTF or a corrida
# takes the next number of its kind when it gets the kind (DTF-863, CR-4114);
# changing the kind gives a new one, the old is never reused. The cor lisa's
# number comes with its color family (2.5b). "Entra no catálogo"
# (no_catalogo) opens a work without corte to every client — the coleção
# geral; a cor lisa is born in it.
#
# Usage: arte.update!(tipo: "dtf"); arte.codigo # => "DTF-863"
module TipoDaArte
  extend ActiveSupport::Concern

  TIPOS = %w[calcado dtf corrida cor_lisa].freeze
  ROTULOS = { "calcado" => "Calçado", "dtf" => "Etiqueta DTF", "corrida" => "Estampa corrida", "cor_lisa" => "Cor lisa" }.freeze
  # The kinds numbered now, with their code's prefix.
  PREFIXOS = { "dtf" => "DTF", "corrida" => "CR" }.freeze
  # Etapa 2.5c (decided 12/10/2026): sold by the meter, a corrida or a cor
  # lisa has no size either — a DTF keeps its P/M/G or numbers.
  SEM_TAMANHO = %w[corrida cor_lisa].freeze
  # Etapa 2.5c (decided 13/10/2026): a DTF's sizes came numbered by hand one
  # by one (872-ENCRUZILHADA P, 873-… M, 874-… G); now that the system
  # numbers the etiqueta, that leading number doesn't separate them in the
  # upload's grouping (it stays in each file's original name).
  REFERENCIA_NAO_SEPARA = %w[dtf].freeze

  included do
    validates :tipo, inclusion: { in: TIPOS, message: "%{value} is not a kind of arte; expected one of #{TIPOS.join(", ")}" }
    validate :catalogo_so_sem_corte
    before_save :numerar, if: :will_save_change_to_tipo?
    # Etapa 2.5b: an arte that becomes a cor lisa is measured (its name comes with it).
    after_update_commit :medir_cor, if: -> { saved_change_to_tipo? && tipo == "cor_lisa" }
    after_update_commit -> { ArquivoCompactadoTecido.preparar_da_arte!(self) }, if: -> { saved_change_to_tipo? && ArquivoCompactadoTecido::TIPOS.include?(tipo) }
    belongs_to :materia_prima, optional: true
    atribui_por_uuid :materia_prima
    scope :da_colecao_geral, -> { where(no_catalogo: true) }
  end

  class_methods do
    # Usage: Arte.novo_do_tipo("cor_lisa") # => unsaved, in the catálogo
    def novo_do_tipo(tipo)
      tipo = tipo.presence || "calcado"
      new(tipo: tipo, no_catalogo: tipo == "cor_lisa")
    end
  end

  def calcado?
    tipo == "calcado"
  end

  # Parts, sides and pilotos are calçado's (Etapa 2.5c, decided 12/10/2026):
  # a work without corte has none — each of its files is already the editable
  # one, and production compacts (corrida, cor lisa) or lays out (DTF) it.
  def usa_pecas?
    calcado?
  end

  def usa_tamanhos?
    SEM_TAMANHO.exclude?(tipo)
  end

  # What a file of this kind doesn't keep: cleared on every save of the file
  # (MembroDeArte) and on its files when the arte changes kind.
  # Usage: arte.campos_fora_do_tipo # => { peca_id: nil, lado: nil, tamanho_id: nil, tamanho_rotulo: nil }
  def campos_fora_do_tipo
    campos = usa_pecas? ? {} : { peca_id: nil, lado: nil }
    usa_tamanhos? ? campos : campos.merge(tamanho_id: nil, tamanho_rotulo: nil)
  end

  # Usage: arte.codigo # => "DTF-863"; "Laranja 1" for a measured cor lisa;
  #        nil for calçado or a cor lisa not measured yet
  def codigo
    return "#{familia} #{numero}" if tipo == "cor_lisa" && numero

    prefixo = PREFIXOS[tipo]
    "#{prefixo}-#{numero}" if prefixo && numero
  end

  # The cor lisa's family and number, at its first measure (Etapa 2.5b,
  # decided 12/10/2026: the system names it — "Laranja 1" —, numbered per
  # family, never changed by a later version).
  # Usage: arte.batizar!([54.3, 64.7, 55.3]) # => "Laranja 1"
  def batizar!(lab)
    with_lock do
      return codigo if numero

      self.familia = FamiliasDeCor.classificar(lab)
      self.numero = Sequencia.proximo!("cor_lisa:#{familia.parameterize}")
      save!
    end
    codigo
  end

  # The measured color of a cor lisa: its file's version in use.
  # Usage: arte.cor_medida&.cor_hex # => "#EF4123"
  def cor_medida
    principal&.approved_version&.then { |v| v if v.lab }
  end

  # Usage: arte.rotulo_do_tipo # => "Etiqueta DTF"
  def rotulo_do_tipo
    ROTULOS.fetch(tipo)
  end

  # A numbered work without corte (DTF, corrida) is named from its file
  # name, like a calçado arte when its molde is chosen (decided 14/10/2026:
  # "872-ENCRUZILHADA DO SUL- P - 1,6 X 1,7" → "ENCRUZILHADA DO SUL"; the
  # pedido showed only "DTF-4"). The cor lisa is named by the system.
  # Usage: arte.nomeada_pelo_arquivo? # => true for a DTF
  def nomeada_pelo_arquivo?
    PREFIXOS.key?(tipo)
  end

  # Another kind while no pedido uses it (decided 12/10/2026): a pedido read
  # its parts and sizes by the kind it had.
  # Usage: arte.trocar_tipo!("corrida") # => false with errors when refused
  def trocar_tipo!(novo)
    errors.add(:tipo, "can't change: #{titulo} is in a pedido") if ItemPedido.where(arte_id: id).exists?
    errors.add(:tipo, "can't be #{ROTULOS[novo] || novo} while #{titulo} has a molde: unlink it first") if novo != "calcado" && arquivos.where.not(molde_id: nil).exists?
    return false if errors.any?

    transaction do
      raise ActiveRecord::Rollback unless update(tipo: novo, no_catalogo: novo == "cor_lisa" || (no_catalogo && novo != "calcado"))

      limpar_arquivos_fora_do_tipo
      # The principal's name is shared with the arte's other files.
      principal&.nomear_pelo_arquivo! if nomeada_pelo_arquivo?
    end
    errors.none?
  end

  private

  # The cor lisa's number comes with its family, at the first measure (batizar!).
  def numerar
    prefixo = PREFIXOS[tipo]
    self.familia = ""
    self.numero = prefixo ? Sequencia.proximo!(tipo) : nil
  end

  # No pedido uses the arte (trocar_tipo! checks), so nothing reads these.
  def limpar_arquivos_fora_do_tipo
    campos = campos_fora_do_tipo
    campos = campos.merge(papel: "producao") unless usa_pecas?
    arquivos.update_all(campos.merge(updated_at: Time.current)) if campos.any?
  end

  def medir_cor
    versao = principal&.approved_version
    MedirCorJob.perform_later(versao.id) if versao&.status == "processed"
  end

  def catalogo_so_sem_corte
    errors.add(:no_catalogo, "only a work without corte (DTF, estampa corrida, cor lisa) enters the catálogo; this arte is calçado") if no_catalogo && calcado?
  end
end
