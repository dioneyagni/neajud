# Every production stage's lines of a pedido and their state, read once
# (Painel 1/4, decided 04/11/2026). Measured on the dev data: each stage
# rebuilt the pedido's lines and read its baixas again — Impressão,
# Estamparia and Conferência share the same lines —, ~1.200 queries for a
# calçado pedido of 6 items. Here the lines are built once per kind and the
# baixas come in (one query for every pedido of the Painel) or are read once.
#
# Usage: EstadoDasEtapas.call(pedido)["estamparia"].values.map(&:estado) # => [:feita, :aguardando, …]
#        EstadoDasEtapas.call(pedido, baixas: BaixaProducao.vigentes.where(pedido: pedido).to_a)
class EstadoDasEtapas
  # baixas: the pedido's baixas in force (any order); nil reads them.
  def self.call(pedido, baixas: nil)
    new(pedido, baixas).call
  end

  def initialize(pedido, baixas = nil)
    @pedido = pedido
    @baixas = baixas
    @memoria = {}
    @linhas = {}
  end

  # { "impressao" => { chave => Situacao }, … } in the stages' order.
  def call
    EtapasProducao.do_tipo(@pedido.tipo, pedido: @pedido).to_h do |etapa|
      [ etapa.chave, RegistrarBaixaService.situacao(@pedido, etapa.chave, fontes: self) ]
    end
  end

  # The stage's lines (RegistrarBaixaService's source).
  def linhas(etapa)
    @linhas[etapa.chave] ||= LinhasDeProducao.call(@pedido, etapa, memoria: @memoria)
  end

  # The stage's baixas in force, oldest first (RegistrarBaixaService's source).
  def baixas(etapa)
    por_etapa.fetch(etapa.to_s, [])
  end

  private

  def por_etapa
    @por_etapa ||= (@baixas || @pedido.baixas_producao.vigentes.includes(:user).to_a)
                   .select { |baixa| baixa.desfeita_em.nil? }.sort_by { |baixa| [ baixa.created_at, baixa.id ] }.group_by(&:etapa)
  end
end
