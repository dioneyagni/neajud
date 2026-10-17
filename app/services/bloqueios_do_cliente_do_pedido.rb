# The pendências of a pedido whose client is the pedido's (Pedido#cliente_do_pedido?:
# the DTF since Etapa 2.6b1 D4, the tecido since 2.7a), shared by
# PedidoBloqueiosDtf and PedidoBloqueiosTecido:
#   :pedido_sem_cliente — the team picks it on the pedido page;
#   :arte_de_outro_cliente — an arte outside the catálogo belongs to another
#                 client, or to none.
# The including class has @pedido and `itens` (with :arte and :arquivo).
#
# Usage: sem_cliente + de_outro_cliente("Etiqueta")
module BloqueiosDoClienteDoPedido
  private

  def sem_cliente
    return [] if @pedido.client_id

    [ PedidoBloqueiosService::Bloqueio.new(tipo: :pedido_sem_cliente, descricao: "Pedido sem cliente: escolha o cliente do pedido") ]
  end

  def de_outro_cliente(rotulo)
    itens.reject { |item| item.arte.no_catalogo || item.arquivo.client_id == @pedido.client_id }.uniq(&:arte_id).map do |item|
      dono = item.arquivo.client&.name
      descricao = dono ? "#{rotulo} #{item.arte.titulo} é de #{dono}, não do cliente do pedido" : "#{rotulo} #{item.arte.titulo} sem cliente: escolha um, ou marque Entra no catálogo"
      PedidoBloqueiosService::Bloqueio.new(tipo: :arte_de_outro_cliente, descricao: descricao, arquivo: item.arquivo)
    end
  end
end
