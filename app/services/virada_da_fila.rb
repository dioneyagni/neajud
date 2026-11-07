# The virada (Painel 3/4b, decided 07/11/2026, Q4a–Q6a): a new turno's
# photo against the one before. It changes no order — what didn't end is
# still ahead of whatever arrived later (Q4a) —; it tells. Each pedido
# whose previsão moved to a later day gets a ViradaDoPedido (the team's
# history: which stages programmed to end in the turno before didn't, and
# whether it came to be late, the warning at the Painel's top) and the
# cliente final's "previsão mudou" (AvisoDePrevisao, no person). What a move
# in the queue already told during the turno is not told again.
#
# Usage: ViradaDaFila.call(foto_anterior, foto_nova, fila) # => [ViradaDoPedido]
class ViradaDaFila
  # Stages kept by name in the record (the history line stays short).
  NAO_TERMINARAM = 10

  def self.call(anterior, nova, fila)
    new(anterior, nova, fila).call
  end

  def initialize(anterior, nova, fila)
    @anterior, @nova, @fila = anterior, nova, fila
    @abertas = fila.pedidos.flat_map { |pedido| fila.previsao(pedido).vezes }.index_by { |vez| [ vez.pedido.id, vez.etapa.chave ] }
  end

  def call
    antes = @anterior.vezes.to_a.group_by(&:pedido_id)
    @fila.pedidos.filter_map do |pedido|
      de = antes[pedido.id]&.first&.previsao
      registrar(pedido, de) if de
    end
  end

  private

  def registrar(pedido, de)
    contados = ja_contado(pedido)
    para = @fila.previsao(pedido).fim
    return if para.nil? && contados.include?(nil)

    de = [ de, *contados.compact ].max
    return unless AvisoDePrevisao.mudou_de_dia?(de, para)

    AvisoDePrevisao.call(pedido, de: de, para: para)
    ViradaDoPedido.create!(pedido: pedido, turno_nome: @nova.turno_nome, data: @nova.data, turno_fim: @nova.fim, de: de, para: para,
                           passou_a_atrasar: AvisoDePrevisao.passa_a_atrasar?(AvisoDePrevisao.prazo(pedido), de, para), nao_terminaram: nao_terminaram_para(pedido))
  end

  # The previsões a move in the queue gave the pedido since the photo before.
  def ja_contado(pedido)
    @movimentos ||= MovimentoDaFila.where(created_at: @anterior.created_at..).to_a
    @movimentos.filter_map { |movimento| movimento.empurrado(pedido) }.map { |e| e["para"] && Time.zone.parse(e["para"]) }
  end

  # The stages the photo before had end in its turno, still open now — the
  # pedido's own first, then the ones ahead of it in their sector's queue
  # (the ones that held it): those tell it most. 3/4b2: the whole uuid
  # ("quem cruzou" marks that pedido's row) and a_frente — only the ones
  # ahead pushed it; the others merely didn't end either.
  def nao_terminaram_para(pedido)
    lugares = @anterior.vezes.select { |linha| linha.pedido_id == pedido.id && linha.posicao }.group_by(&:setor).transform_values { |l| l.map(&:posicao).max }
    entradas = nao_terminaram.map { |linha, vez| [ vez, linha.pedido_id != pedido.id && a_frente?(linha, lugares) ] }
    proprias, outras = entradas.partition { |vez, _| vez.pedido.id == pedido.id }
    (proprias + outras.sort_by { |_, frente| frente ? 0 : 1 }).first(NAO_TERMINARAM).map do |vez, frente|
      { "pedido" => vez.pedido.uuid, "etapa" => vez.etapa.nome, "veio_de" => @anterior.turno_nome, "a_frente" => frente }
    end
  end

  def a_frente?(linha, lugares)
    lugar = lugares[linha.setor]
    lugar.present? && linha.posicao.present? && linha.posicao < lugar
  end

  # [VezDaFoto, the stage open now]
  def nao_terminaram
    @nao_terminaram ||= @anterior.vezes.select(&:terminaria_no_turno?).filter_map do |linha|
      vez = @abertas[[ linha.pedido_id, linha.etapa ]]
      [ linha, vez ] if vez
    end
  end
end
