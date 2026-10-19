# A tecido draft's edited prices (Etapa 2.7b, decided 17/10/2026, Q4): each
# item's print per meter and, when the fabric is the empresa's, its fabric
# per meter; blank goes back to the starting one, which stays beside to
# measure the discount. The team's, with "ver valores".
class PrecosDoPedidoTecidoController < ApplicationController
  include NumeroDigitado

  CAMPOS = %w[preco_impressao_metro preco_tecido_metro].freeze

  exige :pedidos, :editar
  exige_acao :ver_valores
  exige_equipe
  before_action :set_pedido

  # Usage: PATCH /pedidos/:uuid/tecido/preco_item, item_uuid=…, preco_impressao_metro=16,5, preco_tecido_metro=
  def item
    item = @pedido.itens_pedido.por_uuid!(params[:item_uuid])
    item.assign_attributes(CAMPOS.select { |campo| params.key?(campo) }.index_with { |campo| decimal_digitado(params[campo]) })
    return redirect_to resumo_pedido_path(@pedido, anchor: "valores-tecido"), notice: "#{item.arte.titulo}: prices updated." if item.save

    redirect_to resumo_pedido_path(@pedido, anchor: "valores-tecido"), alert: "#{item.arte.titulo}: #{item.errors.full_messages.to_sentence}"
  end

  private

  def set_pedido
    @pedido = visiveis(Pedido).where(tipo: "tecido").por_uuid!(params[:uuid])
    return if @pedido.editavel?

    redirect_to resumo_pedido_path(@pedido), alert: "#{@pedido.rotulo_lixeira} is #{@pedido.excluido? ? "in the trash" : @pedido.status}; its prices change only while editable"
  end
end
