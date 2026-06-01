class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound do
    respond_to do |format|
      format.html { render plain: "Not found", status: :not_found }
      format.json { render json: { error: "Not found" }, status: :not_found }
      format.turbo_stream { head :not_found }
    end
  end
end
