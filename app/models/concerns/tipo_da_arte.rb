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

  # Usage: arte.codigo # => "DTF-863", nil for calçado or a cor lisa (2.5b)
  def codigo
    prefixo = PREFIXOS[tipo]
    "#{prefixo}-#{numero}" if prefixo && numero
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

  def numerar
    prefixo = PREFIXOS[tipo]
    self.numero = prefixo ? Sequencia.proximo!(tipo) : nil
  end

  def catalogo_so_sem_corte
    errors.add(:no_catalogo, "only a work without corte (DTF, estampa corrida, cor lisa) enters the catálogo; this arte is calçado") if no_catalogo && calcado?
  end
end
