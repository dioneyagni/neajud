# Marks a pedido delivered (Etapa 2.2, 3/3; decided 07/10/2026). Never
# locked: when stages still have open lines it answers :aviso naming them,
# and delivering anyway (a client takes what is ready) needs `confirmar`.
# A delivered pedido is read only: no more baixas, none undone. A reposição
# still in production warns the same way (4/4: deliver what is ready, or wait).
# Material it still waits for (decided 05/11/2026): delivered, it would stop
# showing as waiting with the stock short — so, like a baixa, it answers
# :falta_material until the entry comes with it (EntradaDaFalta).
#
# Usage: EntregarPedidoService.call(pedido, confirmar: false, user: u, entradas: nil, autorizador: nil)
#   # => #<Resultado estado=:aviso mensagem="Ainda faltam: Corte 2 linhas, Conferência 5 linhas. Entregar assim mesmo?">
class EntregarPedidoService
  Resultado = Struct.new(:estado, :mensagem, :faltas, keyword_init: true)

  def self.call(pedido, confirmar: false, user: nil, entradas: nil, autorizador: nil)
    new(pedido, confirmar, user, entradas, autorizador).call
  end

  def initialize(pedido, confirmar, user, entradas, autorizador)
    @pedido = pedido
    @confirmar = confirmar
    @user = user
    @entradas = entradas
    @autorizador = autorizador
  end

  def call
    return Resultado.new(estado: :erro, mensagem: "This pedido is #{@pedido.status}: only a confirmed pedido in production can be delivered.") unless @pedido.em_producao?

    faltando = AndamentoDoPedido.call(@pedido).reject { |a| a.abertas.zero? }
    reposicoes = @pedido.reposicoes.where.not(status: "entregue").to_a
    return Resultado.new(estado: :aviso, mensagem: aviso(faltando, reposicoes)) if (faltando.any? || reposicoes.any?) && !@confirmar

    entregar
  end

  private

  def entregar
    faltas = EntradaDaFalta.faltas(@pedido)
    return Resultado.new(estado: :falta_material, faltas: faltas, mensagem: "Este pedido ainda espera material no estoque. Se ele chegou, lance a entrada para entregar.") if faltas.any? && @entradas.nil?

    Pedido.transaction(requires_new: true) do
      erro = faltas.any? && EntradaDaFalta.call(faltas, origem: { lancada_na_entrega: @pedido }, entradas: @entradas, user: @user, autorizador: @autorizador)
      next Resultado.new(estado: :erro, mensagem: erro) if erro

      @pedido.update!(status: "entregue", entregue_em: Time.current, entregue_por: @user)
      Resultado.new(estado: :ok, mensagem: "Pedido delivered.")
    end
  end

  def aviso(faltando, reposicoes)
    partes = faltando.map { |a| "#{a.etapa.nome} #{a.abertas} #{a.abertas == 1 ? "linha" : "linhas"}" }
    partes += reposicoes.map { |r| "a reposição ##{r.uuid.first(8)}" }
    "Ainda faltam: #{partes.join(", ")}. Entregar assim mesmo?"
  end
end
