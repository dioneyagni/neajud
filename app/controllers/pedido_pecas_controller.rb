# Completes a pending piece (no arte) of a draft pedido by choosing an arte
# already in the system — see ArteCandidatasService and VincularArteService.
class PedidoPecasController < ApplicationController
  before_action :set_peca_row
  before_action :require_pending_in_draft

  # Usage: GET /pedidos/:pedido_uuid/pecas/:id/escolher_arte
  def escolher_arte
    @modelo = @peca_row.item_pedido.arquivo.modelo
    @grupos = ArteCandidatasService.call(@peca_row)
  end

  # Usage: POST /pedidos/:pedido_uuid/pecas/:id/vincular_arte (arquivo_uuid, confirmar_mudanca=1 to move)
  def vincular_arte
    arte = Arquivo.find_by!(uuid: params[:arquivo_uuid])
    VincularArteService.call(@peca_row, arte, changed_by: request.remote_ip,
                                              confirmar_mudanca: params[:confirmar_mudanca] == "1")
    redirect_to resumo_pedido_path(@pedido), notice: "Arte #{arte.filename} vinculada à peça #{@peca_row.peca.nome}."
  rescue VincularArteService::Recusado => e
    redirect_to escolher_arte_pedido_peca_path(@pedido, @peca_row), alert: e.message
  end

  private

  def set_peca_row
    @pedido = Pedido.find_by!(uuid: params[:pedido_uuid])
    @peca_row = ItemPedidoPeca.joins(:item_pedido).where(itens_pedido: { pedido_id: @pedido.id }).find(params[:id])
  end

  def require_pending_in_draft
    return if @pedido.status == "rascunho" && @peca_row.arquivo.nil?

    redirect_to resumo_pedido_path(@pedido),
                alert: "Piece #{@peca_row.id} can't be completed: pedido is #{@pedido.status} and the piece #{@peca_row.arquivo ? "already has an arte" : "is pending"}."
  end
end
