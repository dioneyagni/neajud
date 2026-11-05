# Each production stage's progress in a pedido (Etapa 2.2, 3/3): lines done
# and lines in all, for the pedido's panel, the list and the delivery's
# warning. Read through EstadoDasEtapas (Painel 1/4): every stage at once.
#
# Usage: AndamentoDoPedido.call(pedido).map { |a| "#{a.etapa.nome} #{a.feitas}/#{a.total}" } # => ["Impressão 3/5", …]
class AndamentoDoPedido
  Andamento = Struct.new(:etapa, :feitas, :total, keyword_init: true) do
    def abertas
      total - feitas
    end
  end

  # estados: EstadoDasEtapas already computed for the pedido.
  def self.call(pedido, estados: EstadoDasEtapas.call(pedido))
    EtapasProducao.do_tipo(pedido.tipo, pedido: pedido).map do |etapa|
      situacoes = estados.fetch(etapa.chave).values
      Andamento.new(etapa: etapa, feitas: situacoes.count { |s| s.estado == :feita }, total: situacoes.size)
    end
  end
end
