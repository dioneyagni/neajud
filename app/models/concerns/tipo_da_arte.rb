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

  included do
    validates :tipo, inclusion: { in: TIPOS, message: "%{value} is not a kind of arte; expected one of #{TIPOS.join(", ")}" }
    validate :catalogo_so_sem_corte
    before_save :numerar, if: :will_save_change_to_tipo?
    # Etapa 2.5b: an arte that becomes a cor lisa is measured (its name comes with it).
    after_update_commit :medir_cor, if: -> { saved_change_to_tipo? && tipo == "cor_lisa" }
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

  # Another kind while no pedido uses it (decided 12/10/2026): a pedido read
  # its parts and sizes by the kind it had.
  # Usage: arte.trocar_tipo!("corrida") # => false with errors when refused
  def trocar_tipo!(novo)
    errors.add(:tipo, "can't change: #{titulo} is in a pedido") if ItemPedido.where(arte_id: id).exists?
    errors.add(:tipo, "can't be #{ROTULOS[novo] || novo} while #{titulo} has a molde: unlink it first") if novo != "calcado" && arquivos.where.not(molde_id: nil).exists?
    return false if errors.any?

    update(tipo: novo, no_catalogo: novo == "cor_lisa" || (no_catalogo && novo != "calcado"))
  end

  private

  # The cor lisa's number comes with its family, at the first measure (batizar!).
  def numerar
    prefixo = PREFIXOS[tipo]
    self.familia = ""
    self.numero = prefixo ? Sequencia.proximo!(tipo) : nil
  end

  def medir_cor
    versao = principal&.approved_version
    MedirCorJob.perform_later(versao.id) if versao&.status == "processed"
  end

  def catalogo_so_sem_corte
    errors.add(:no_catalogo, "only a work without corte (DTF, estampa corrida, cor lisa) enters the catálogo; this arte is calçado") if no_catalogo && calcado?
  end
end
