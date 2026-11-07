# "Mostrar quem cruzou" in the faixa's timeline (Painel 3/4b3, the form of
# Q16a, 04/11/2026): a lane per pedido that crossed this one (pushed it or
# was pushed by it, CruzamentosDoPedido), its stages where they crossed
# filling the same turnos — orange, so who took this pedido's turnos shows.
# The queue of now (FilaDeProducao) gives their pieces; a stage already done
# has none (its past pieces live only in the photos) and says so.
#
# Usage: CruzadasNoTempo.call(cruzamentos, colunas: tempo.colunas, fila: fila)
#        # => [#<RaiaCruzada outro=#<Pedido…>, etapas=["Impressão"], celulas=[nil, 0.5], feita=false, cruzamentos=[…]>]
class CruzadasNoTempo
  # etapas: the names of the stages where they crossed; feita: none of them
  # is in the queue any more; cruzamentos: the causes, by time.
  RaiaCruzada = Struct.new(:outro, :etapas, :celulas, :feita, :cruzamentos, keyword_init: true)

  def self.call(cruzamentos, colunas:, fila:)
    cruzamentos.group_by(&:outro).map { |outro, deles| new(outro, deles, colunas, fila).raia }
  end

  def initialize(outro, cruzamentos, colunas, fila)
    @outro, @cruzamentos, @colunas = outro, cruzamentos, colunas
    @abertas = fila.previsao(outro)&.vezes || []
  end

  def raia
    pares = @cruzamentos.map { |cruzamento| [ cruzamento, vez_de(cruzamento) ] }
    vezes = pares.filter_map(&:last).uniq
    periodos = vezes.flat_map(&:trechos).map { |trecho| [ trecho.inicio, trecho.fim ] }
    RaiaCruzada.new(outro: @outro, etapas: etapas_em_ordem(pares),
                    celulas: @colunas.map { |coluna| coluna.parte(periodos) }, feita: vezes.empty?, cruzamentos: @cruzamentos)
  end

  private

  # The other pedido's open stage where they crossed: a move's by its sector
  # (a pedido of another tipo has its own stage there), a virada's by the
  # name it kept.
  def vez_de(cruzamento)
    return @abertas.find { |vez| vez.setor == cruzamento.movimento.setor } if cruzamento.movimento

    @abertas.find { |vez| vez.etapa.nome == cruzamento.etapa }
  end

  # The names in the order of its path (the open ones as the queue has
  # them, the done ones after), not of the crossings.
  def etapas_em_ordem(pares)
    pares.sort_by.with_index { |(_, vez), i| [ vez ? @abertas.index(vez) : @abertas.size, i ] }
         .map { |cruzamento, vez| nome_da_etapa(cruzamento, vez) }.uniq
  end

  # A move's stage done: the sector's name.
  def nome_da_etapa(cruzamento, vez)
    vez&.etapa&.nome || cruzamento.etapa || LinhaDoPainel::COLUNAS.fetch(cruzamento.movimento.setor)
  end
end
