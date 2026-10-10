class ApplicationController < ActionController::Base
  include Authentication
  include ControleDeAcesso
  include ControleDeVisibilidade
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

  # Who did it, for every log and for deleted_by/restored_by: the logged-in
  # user plus the request IP (all that rows before Etapa 0.5 have).
  # Usage: record.excluir!(**autoria)
  def autoria
    { changed_by: request.remote_ip, user: Current.user }
  end

  # Not visiveis: the header's count is no proof the action used the policy.
  def load_current_pedido_count
    pedido = visibilidade.escopo(Pedido).ativos.find_by(uuid: session[:current_pedido_uuid])
    @current_pedido_count = pedido&.total_itens || 0
  end
end
