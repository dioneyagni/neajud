# What moving a stage in its sector's queue does (Painel 3/4a, decided
# 07/11/2026, Q3a, Q5a), before anyone confirms it: the queue computed again
# with the move and compared — every pedido whose previsão gets worse, in any
# sector (the cascade), the ones that come to be late first; the reason is
# required only then. The moved pedido apart, with what it gains.
#
# Three moves: a stage to a place (posicao), a stage back to its arrival
# (posicao nil), every moved stage of a sector back (setor, no etapa). A
# place before the stages under way (a baixa given, Q6b) is not one: it
# goes right after them.
#
# Usage: impacto = ImpactoDoMovimento.call(fila, pedido: p, etapa: "impressao", posicao: 1)
#        impacto.empurrados.map { |e| [ e.pedido.uuid.first(8), e.passa_a_atrasar ] } # => [["b910aa12", true]]
#        impacto.exige_motivo? # => true
class ImpactoDoMovimento
  # The stage can't move: it isn't in the queue, has no previsão or is under way.
  class Invalido < StandardError; end

  Empurrado = Struct.new(:pedido, :de, :para, :prazo, :passa_a_atrasar, keyword_init: true) do
    def folga
      prazo && para && (prazo - para.to_date).to_i
    end
  end

  # tipo: :posicao, :chegada (one stage back), :setor (every moved one back).
  # movimentos: the MovimentoDaFila to save (unsaved). movidos: { pedido => [de, para] }.
  Impacto = Struct.new(:tipo, :setor, :vez, :de, :para, :limite, :total, :movimentos, :movidos, :empurrados, keyword_init: true) do
    def exige_motivo?
      empurrados.any?(&:passa_a_atrasar)
    end

    def muda?
      movimentos.any?
    end
  end

  def self.call(fila, pedido: nil, etapa: nil, posicao: nil, setor: nil)
    new(fila).call(pedido, etapa, posicao, setor)
  end

  def initialize(fila)
    @fila = fila
  end

  def call(pedido, etapa, posicao, setor)
    return de_volta_o_setor(setor) if etapa.blank?

    vez = vez_de(pedido, etapa)
    posicao ? para_a_posicao(vez, posicao) : de_volta(vez)
  end

  private

  def vez_de(pedido, etapa)
    vez = @fila.previsao(pedido)&.vezes&.find { |outra| outra.etapa.chave == etapa.to_s }
    raise Invalido, "#{etapa.inspect} of pedido #{pedido.uuid} is not in a queue; expected an open stage with previsão" unless vez&.posicao
    raise Invalido, "#{vez.etapa.nome} of pedido #{pedido.uuid} is under way (a baixa was given); it can't move" if vez.iniciada?

    vez
  end

  def previstas(setor)
    @fila.do_setor(setor).select(&:fim)
  end

  # It sorts as if it arrived just before the one at that place (going up)
  # or just after it (going down): the order holds while others end or arrive.
  def para_a_posicao(vez, posicao)
    lista = previstas(vez.setor)
    limite = lista.count(&:iniciada?) + 1
    para = posicao.clamp(limite, lista.size)
    alvo = lista[para - 1]
    ordem_em = alvo.ordem[1] + (para < vez.posicao ? -0.001 : 0.001)
    movimento = MovimentoDaFila.new(pedido: vez.pedido, etapa: vez.etapa.chave, setor: vez.setor, de: vez.posicao, para: para, ordem_em: ordem_em)
    movimentos = para == vez.posicao ? [] : [ movimento ]
    comparar(:posicao, vez.setor, movimentos, vez: vez, limite: limite, total: lista.size)
  end

  def de_volta(vez)
    raise Invalido, "#{vez.etapa.nome} of pedido #{vez.pedido.uuid} is in its arrival order already" unless vez.movimento

    movimento = MovimentoDaFila.new(pedido: vez.pedido, etapa: vez.etapa.chave, setor: vez.setor, de: vez.posicao)
    comparar(:chegada, vez.setor, [ movimento ], vez: vez)
  end

  def de_volta_o_setor(setor)
    movidas = @fila.do_setor(setor.to_s).select(&:movimento)
    raise Invalido, "the #{setor.inspect} queue has no moved stage; expected one moved by a person" if movidas.empty?

    movimentos = movidas.map { |vez| MovimentoDaFila.new(pedido: vez.pedido, etapa: vez.etapa.chave, setor: vez.setor, de: vez.posicao) }
    comparar(:setor, setor.to_s, movimentos)
  end

  # The queue again with the moves, against the one now.
  def comparar(tipo, setor, movimentos, vez: nil, limite: nil, total: nil)
    depois = FilaDeProducao.call(**@fila.entradas, ordens: ordens_com(movimentos))
    movimentos.each { |m| m.para ||= posicao_em(depois, m) }
    movidos = movimentos.map(&:pedido).uniq
    Impacto.new(tipo: tipo, setor: setor, vez: vez, de: vez&.posicao, para: movimentos.first&.para || vez&.posicao, limite: limite, total: total,
                movimentos: movimentos, movidos: movidos.to_h { |p| [ p, [ fim(@fila, p), fim(depois, p) ] ] },
                empurrados: empurrados(depois, movidos))
  end

  def ordens_com(movimentos)
    movimentos.each_with_object(@fila.ordens.dup) do |movimento, ordens|
      chave = [ movimento.pedido.id, movimento.etapa ]
      movimento.ordem_em ? ordens[chave] = movimento : ordens.delete(chave)
    end
  end

  def posicao_em(fila, movimento)
    fila.do_setor(movimento.setor).find { |v| v.pedido.id == movimento.pedido.id && v.etapa.chave == movimento.etapa }&.posicao
  end

  def fim(fila, pedido)
    fila.previsao(pedido)&.fim
  end

  # The ones whose previsão got worse (or lost), the newly late first.
  def empurrados(depois, movidos)
    lista = (@fila.pedidos - movidos).filter_map do |pedido|
      de, para = fim(@fila, pedido), fim(depois, pedido)
      next unless de && (para.nil? || para > de)

      prazo = AvisoDePrevisao.prazo(pedido)
      Empurrado.new(pedido: pedido, de: de, para: para, prazo: prazo, passa_a_atrasar: AvisoDePrevisao.passa_a_atrasar?(prazo, de, para))
    end
    lista.sort_by { |e| [ e.passa_a_atrasar ? 0 : 1, e.de ] }
  end
end
