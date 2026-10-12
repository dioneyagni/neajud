module ApplicationHelper
  # Who made a logged change: the user's name, else the IP (logs written
  # before Etapa 0.5 have only the IP).
  # Usage: <%= autor_do_log(log) %> # => "Ana" or "192.168.0.10"
  def autor_do_log(log)
    log&.user&.nome || log&.changed_by
  end

  # A pedido's items and pieces can change here: a draft not in the trash,
  # and the user's função may edit pedidos (Etapa 0.5); one sent to the
  # factory only for the team (Etapa 2.8, 5/5).
  # Usage: <% if pedido_editavel?(@pedido) %>…<% end %>
  def pedido_editavel?(pedido)
    pedido.editavel?(cliente_final: cliente_final?) && pode?(:pedidos, :editar)
  end

  def current_pedido_count
    pedido = visiveis(Pedido).ativos.find_by(uuid: session[:current_pedido_uuid])
    pedido ? pedido.total_itens : 0
  end

  # The clients' pedidos waiting for the factory (Etapa 2.8, 5/5), counted
  # next to Pedidos in the header — the team's only.
  # Usage: aguardando_fabrica_count # => 2
  def aguardando_fabrica_count
    return 0 if cliente_final? || !pode?(:pedidos, :editar)

    visiveis(Pedido).ativos.where(status: "enviado").count
  end

  def current_pedido_uuid
    session[:current_pedido_uuid]
  end

  # Stock quantities are linear meters (Etapa 2.3).
  # Usage: metros(12.5) # => "12,5 m"
  def metros(valor)
    "#{number_with_precision(valor, precision: 2, separator: ",", delimiter: ".", strip_insignificant_zeros: true)} m"
  end

  # Prices and costs (Etapa 2.4); "—" when unknown.
  # Usage: reais(1234.5) # => "R$ 1.234,50"
  def reais(valor)
    return "—" if valor.nil?

    "R$ #{number_with_precision(valor, precision: 2, separator: ",", delimiter: ".")}"
  end
end
