# Marks a pedido delivered (Etapa 2.2, 3/3; decided 07/10/2026). Never
# locked: when stages still have open lines it answers :aviso naming them,
# and delivering anyway (a client takes what is ready) needs `confirmar`.
# A delivered pedido is read only: no more baixas, none undone. A reposição
# still in production warns the same way (4/4: deliver what is ready, or wait).
#
# Usage: EntregarPedidoService.call(pedido, confirmar: false, user: u)
#   # => #<Resultado estado=:aviso mensagem="Ainda faltam: Corte 2 linhas, Conferência 5 linhas. Entregar assim mesmo?">
class EntregarPedidoService
  Resultado = Struct.new(:estado, :mensagem, keyword_init: true)

  def self.call(pedido, confirmar: false, user: nil)
    new(pedido, confirmar, user).call
  end

  def initialize(pedido, confirmar, user)
    @pedido = pedido
    @confirmar = confirmar
    @user = user
  end

  def call
    return Resultado.new(estado: :erro, mensagem: "This pedido is #{@pedido.status}: only a confirmed pedido in production can be delivered.") unless @pedido.em_producao?

    faltando = AndamentoDoPedido.call(@pedido).reject { |a| a.abertas.zero? }
    reposicoes = @pedido.reposicoes.where.not(status: "entregue").to_a
    return Resultado.new(estado: :aviso, mensagem: aviso(faltando, reposicoes)) if (faltando.any? || reposicoes.any?) && !@confirmar

    @pedido.update!(status: "entregue", entregue_em: Time.current, entregue_por: @user)
    Resultado.new(estado: :ok, mensagem: "Pedido delivered.")
  end

  private

  def aviso(faltando, reposicoes)
    partes = faltando.map { |a| "#{a.etapa.nome} #{a.abertas} #{a.abertas == 1 ? "linha" : "linhas"}" }
    partes += reposicoes.map { |r| "a reposição ##{r.uuid.first(8)}" }
    "Ainda faltam: #{partes.join(", ")}. Entregar assim mesmo?"
  end
end
