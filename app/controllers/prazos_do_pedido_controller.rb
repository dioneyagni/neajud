# The delivery date promised to the client (Painel 1/4): the team sets it,
# before or after confirming — a confirmed pedido is otherwise frozen. The
# Painel orders and flags the late ones by it.
class PrazosDoPedidoController < ApplicationController
  exige :pedidos, :editar
  exige_equipe

  # Usage: PATCH /pedidos/:uuid/prazo, prazo_entrega=2026-11-20 (blank clears it)
  def update
    pedido = visiveis(Pedido).por_uuid!(params[:uuid])
    return redirect_to resumo_pedido_path(pedido), alert: "Pedido in the trash: restore it first." if pedido.excluido?

    prazo = params[:prazo_entrega].presence
    data = prazo && (Date.iso8601(prazo) rescue nil)
    return redirect_to resumo_pedido_path(pedido), alert: "Prazo #{prazo.inspect} is not a date; expected YYYY-MM-DD." if prazo && data.nil?

    if pedido.update(prazo_entrega: data)
      redirect_to resumo_pedido_path(pedido), notice: "Prazo de entrega atualizado."
    else
      redirect_to resumo_pedido_path(pedido), alert: pedido.errors.full_messages.to_sentence
    end
  end
end
