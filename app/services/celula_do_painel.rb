# A cell of the Painel (Painel 1/4, decided 04/11/2026 Q6a): a pedido in one
# column, as a state with a short text; the detail shows on hover.
#
#   :feita        — done
#   :andamento    — some lines done (feitas/total)
#   :pode_comecar — nothing waits: the stage may start
#   :travada      — waits for another stage, or for material
#   :pendencia    — something to settle before it can go on
#   :nao_tem      — the pedido doesn't go through this column
#   :ainda_nao    — not its turn yet (a draft's production)
# :programada comes with the programação (Painel 3/4).
#
# Usage: CelulaDoPainel.da_etapa(situacoes, confirmado: true).estado # => :travada
class CelulaDoPainel < Struct.new(:estado, :texto, :detalhe, :feitas, :total, keyword_init: true)
  ESTADOS = %i[feita andamento pode_comecar travada pendencia nao_tem ainda_nao].freeze

  # Usage: CelulaDoPainel.nova(:feita, "confirmado") # => #<CelulaDoPainel estado=:feita …>
  def self.nova(estado, texto = nil, detalhe = nil)
    raise ArgumentError, "#{estado.inspect} is not a Painel cell state; expected one of #{ESTADOS.join(", ")}" unless ESTADOS.include?(estado)

    new(estado: estado, texto: texto, detalhe: detalhe)
  end

  # A production stage's cell from its lines' situations (RegistrarBaixaService.situacao).
  # confirmado: the pedido may take baixas; before it, the stage is :ainda_nao.
  def self.da_etapa(situacoes, confirmado:)
    estados = situacoes.map(&:estado)
    feitas = estados.count(:feita)
    return nova(:nao_tem) if estados.empty?

    celula = estado_das_linhas(situacoes, feitas, confirmado)
    celula.feitas = feitas
    celula.total = estados.size
    celula
  end

  def self.estado_das_linhas(situacoes, feitas, confirmado)
    return nova(:feita, "feita") if feitas == situacoes.size
    return nova(:andamento, "#{feitas}/#{situacoes.size}") if feitas.positive?
    return nova(:ainda_nao, "—") unless confirmado
    return nova(:pode_comecar, "pode começar") if situacoes.any? { |s| s.estado == :aberta }

    espera = situacoes.map(&:aguardando).compact.uniq
    nova(:travada, "espera #{espera.join(" e ")}")
  end
  private_class_method :estado_das_linhas

  # Usage: celula.percentual # => 40
  def percentual
    total.to_i.zero? ? nil : (feitas * 100 / total)
  end
end
