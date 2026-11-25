# The queue now against the queue with a change (Painel 3/4a, decided
# 07/11/2026; shared since Máquinas 3/5a): every pedido whose previsão got
# worse — later, or lost —, the ones that come to be late first. A move in
# the queue (ImpactoDoMovimento) and a stop (ImpactoDaParada) both show
# and keep it.
#
# Usage: ComparacaoDaFila.empurrados(fila, depois, fora: [ pedido_movido ]).map { |e| [ e.pedido.uuid.first(8), e.passa_a_atrasar ] } # => [["b910aa12", true]]
class ComparacaoDaFila
  Empurrado = Struct.new(:pedido, :de, :para, :prazo, :passa_a_atrasar, keyword_init: true) do
    def folga
      prazo && para && (prazo - para.to_date).to_i
    end
  end

  # fora: the pedidos the change itself moved (shown apart).
  def self.empurrados(antes, depois, fora: [])
    lista = (antes.pedidos - fora).filter_map do |pedido|
      de, para = fim(antes, pedido), fim(depois, pedido)
      next unless de && (para.nil? || para > de)

      prazo = AvisoDePrevisao.prazo(pedido)
      Empurrado.new(pedido: pedido, de: de, para: para, prazo: prazo, passa_a_atrasar: AvisoDePrevisao.passa_a_atrasar?(prazo, de, para))
    end
    lista.sort_by { |e| [ e.passa_a_atrasar ? 0 : 1, e.de ] }
  end

  # Usage: ComparacaoDaFila.fim(fila, pedido) # => the previsão's end, or nil
  def self.fim(fila, pedido)
    fila.previsao(pedido)&.fim
  end
end
