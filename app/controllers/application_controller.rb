class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :load_current_pedido_count

  rescue_from ActiveRecord::RecordNotFound do
    respond_to do |format|
      format.html { render plain: "Not found", status: :not_found }
      format.json { render json: { error: "Not found" }, status: :not_found }
      format.turbo_stream { head :not_found }
    end
  end

  private

  def load_current_pedido_count
    pedido = Pedido.find_by(uuid: session[:current_pedido_uuid])
    @current_pedido_count = pedido&.total_itens || 0
  end
end
