# Completes a pending piece (no arte) of a draft pedido: by choosing an arte
# already in the system (ArteCandidatasService) or by uploading a new one;
# both link through VincularArteService.
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
    arte = Arquivo.ativos.find_by!(uuid: params[:arquivo_uuid])
    VincularArteService.call(@peca_row, arte, **autoria,
                                              confirmar_mudanca: params[:confirmar_mudanca] == "1")
    redirect_to resumo_pedido_path(@pedido), notice: "Arte #{arte.filename} vinculada à peça #{@peca_row.peca.nome}."
  rescue VincularArteService::Recusado => e
    redirect_to escolher_arte_pedido_peca_path(@pedido, @peca_row), alert: e.message
  end

  # Uploads a new arte straight into the pending piece: created with the
  # modelo's client (ArquivoUploadService), then linked like a chosen one.
  # Usage: POST /pedidos/:pedido_uuid/pecas/:id/enviar_arte (original_file)
  def enviar_arte
    erro = enviar_arte_error(params[:original_file])
    return redirect_to resumo_pedido_path(@pedido), alert: erro if erro

    arte = ArquivoUploadService.call(params[:original_file], remote_ip: request.remote_ip,
                                                             arquivo: Arquivo.new(client_id: @peca_row.item_pedido.arquivo.modelo.client_id))
    return redirect_to resumo_pedido_path(@pedido), alert: "Upload failed: #{arte.errors.full_messages.to_sentence}" unless arte.persisted?

    VincularArteService.call(@peca_row, arte, **autoria)
    redirect_to resumo_pedido_path(@pedido), notice: "Arte #{arte.filename} enviada e vinculada à peça #{@peca_row.peca.nome}."
  rescue VincularArteService::Recusado => e
    redirect_to resumo_pedido_path(@pedido), alert: e.message
  end

  private

  # Only arte files can be printed on a piece (a DXF is a corte).
  def enviar_arte_error(upload)
    return "Select a file to upload." unless upload.respond_to?(:original_filename)

    ext = File.extname(upload.original_filename).delete(".").downcase
    return nil if FileCategory.for_extension(ext) == "artes"

    "#{upload.original_filename} is not an arte file; accepted: #{FileCategory.all["artes"][:extensions].join(", ")}"
  end

  def set_peca_row
    @pedido = Pedido.ativos.find_by!(uuid: params[:pedido_uuid])
    @peca_row = ItemPedidoPeca.joins(:item_pedido).where(itens_pedido: { pedido_id: @pedido.id }).find(params[:id])
  end

  def require_pending_in_draft
    return if @pedido.status == "rascunho" && @peca_row.arquivo.nil?

    redirect_to resumo_pedido_path(@pedido),
                alert: "Piece #{@peca_row.id} can't be completed: pedido is #{@pedido.status} and the piece #{@peca_row.arquivo ? "already has an arte" : "is pending"}."
  end
end
