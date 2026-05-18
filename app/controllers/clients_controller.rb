class ClientsController < ApplicationController
  def search
    clients = Client.search(params[:q]).limit(10)
    render json: clients.map { |c| { id: c.id, name: c.name, responsible: c.responsible } }
  end

  def create
    @client = Client.new(client_params)
    if @client.save
      redirect_back fallback_location: stamps_path, notice: "Client registered."
    else
      redirect_back fallback_location: stamps_path, alert: @client.errors.full_messages.join(", ")
    end
  end

  private

  def client_params
    params.require(:client).permit(:name, :responsible)
  end
end
