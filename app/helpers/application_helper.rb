module ApplicationHelper
  def current_pedido_count
    pedido = Pedido.find_by(uuid: session[:current_pedido_uuid])
    pedido ? pedido.total_itens : 0
  end

  def current_pedido_uuid
    session[:current_pedido_uuid]
  end
end
