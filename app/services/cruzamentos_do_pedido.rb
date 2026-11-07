# "Quem cruzou" a pedido (Painel 3/4b2, decided 07/11/2026, Q9a): the
# pedidos that pushed it and the ones it pushed, by a move in the queue
# (MovimentoDaFila: its mover and its empurrados) and by a virada
# (ViradaDoPedido: the stages ahead of it in their queue that didn't end in
# the turno before — `a_frente`; one behind merely didn't end either). The
# faixa lists them with the cause and the day, and marks their rows. The
# team's only: a cliente final reads none of these records.
#
# Usage: cruzamentos = CruzamentosDoPedido.call(pedidos, historicos: { id => [movimento, virada] }, viradas: visiveis(ViradaDoPedido), visiveis: visiveis(Pedido))
#        cruzamentos[pedido.id].map { |c| [ c.outro.uuid, c.papel, c.tipo ] } # => [["c210…", :empurrou, :movimento]]
class CruzamentosDoPedido
  # papel: :empurrou (the other pushed this one) or :foi_empurrado (this one
  # pushed it); tipo: :movimento or :virada; quando: its created_at.
  # movimento / virada: the record, for its texts.
  Cruzamento = Struct.new(:outro, :papel, :tipo, :etapa, :quando, :movimento, :virada, keyword_init: true)

  # pedidos: the ones asked for; historicos: each one's movements and viradas
  # (the Painel's "Histórico da programação"); viradas / visiveis: the
  # records the person sees, to look up the other viradas and pedidos.
  def self.call(pedidos, historicos:, viradas:, visiveis:)
    new(pedidos, historicos, viradas, visiveis).call
  end

  def initialize(pedidos, historicos, viradas, visiveis)
    @pedidos, @historicos, @visiveis = pedidos, historicos, visiveis
    @alheias = pedidos.empty? ? [] : viradas.esperaram_por(pedidos).includes(:pedido).to_a
  end

  # { pedido id => [Cruzamento] by time }
  def call
    @pedidos.to_h do |pedido|
      registros = @historicos.fetch(pedido.id, [])
      cruzamentos = registros.flat_map { |registro| do_registro(registro, pedido) } + esperaram(pedido)
      [ pedido.id, cruzamentos.select { |c| c.outro && c.outro.id != pedido.id }.each_with_index.sort_by { |c, i| [ c.quando, i ] }.map(&:first) ]
    end
  end

  private

  def do_registro(registro, pedido)
    return da_virada(registro, pedido) if registro.is_a?(ViradaDoPedido)
    return empurrados(registro) if registro.pedido_id == pedido.id

    [ cruzamento(registro.pedido, :empurrou, :movimento, registro) ]
  end

  # The ones this pedido's move made worse.
  def empurrados(movimento)
    movimento.empurrados.map { |e| cruzamento(por_id[e["pedido_id"]], :foi_empurrado, :movimento, movimento) }
  end

  # The other pedidos' stages ahead of it that didn't end, at this one's virada.
  def da_virada(virada, pedido)
    virada.nao_terminaram.select { |e| e["a_frente"] }.map do |e|
      cruzamento(por_prefixo[e["pedido"].first(8)], :empurrou, :virada, virada, etapa: e["etapa"])
    end
  end

  # Other pedidos' viradas that waited for this one's stages.
  def esperaram(pedido)
    @alheias.flat_map do |virada|
      virada.nao_terminaram_de(pedido).select { |e| e["a_frente"] }.map { |e| cruzamento(virada.pedido, :foi_empurrado, :virada, virada, etapa: e["etapa"]) }
    end
  end

  def cruzamento(outro, papel, tipo, registro, etapa: nil)
    movimento = registro if tipo == :movimento
    Cruzamento.new(outro: outro, papel: papel, tipo: tipo, etapa: etapa, quando: registro.created_at, movimento: movimento,
                   virada: (registro unless movimento))
  end

  # The other pedidos, read once (a pedido not visible stays nil and is left out).
  def por_id
    @por_id ||= @visiveis.where(id: registros.select { |r| r.is_a?(MovimentoDaFila) }.flat_map { |m| m.empurrados.map { |e| e["pedido_id"] } }).index_by(&:id)
  end

  def por_prefixo
    @por_prefixo ||= begin
      prefixos = registros.select { |r| r.is_a?(ViradaDoPedido) }.flat_map { |v| v.nao_terminaram.map { |e| e["pedido"].first(8) } }.uniq
      @visiveis.where("substr(pedidos.uuid, 1, 8) IN (?)", prefixos).index_by { |p| p.uuid.first(8) }
    end
  end

  def registros
    @registros ||= @historicos.values_at(*@pedidos.map(&:id)).compact.flatten
  end
end
