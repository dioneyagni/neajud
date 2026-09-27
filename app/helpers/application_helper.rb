module ApplicationHelper
  # Who made a logged change: the user's name, else the IP (logs written
  # before Etapa 0.5 have only the IP).
  # Usage: <%= autor_do_log(log) %> # => "Ana" or "192.168.0.10"
  def autor_do_log(log)
    log&.user&.nome || log&.changed_by
  end

  # A pedido's items and pieces can change here: a draft not in the trash,
  # and the user's função may edit pedidos (Etapa 0.5).
  # Usage: <% if pedido_editavel?(@pedido) %>…<% end %>
  def pedido_editavel?(pedido)
    pedido.editavel? && pode?(:pedidos, :editar)
  end

  def current_pedido_count
    pedido = Pedido.ativos.find_by(uuid: session[:current_pedido_uuid])
    pedido ? pedido.total_itens : 0
  end

  def current_pedido_uuid
    session[:current_pedido_uuid]
  end
end
