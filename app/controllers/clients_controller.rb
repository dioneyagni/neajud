class ClientsController < ApplicationController
  before_action :set_client, only: %i[show update destroy]

  def index
    @clients = Client.order(:name)
  end

  def show
    @modelos = @client.modelos.order(:nome)
    @arquivos_by_modelo = {}
    @modelos.each do |modelo|
      direct = Arquivo.where(client_id: @client.id, modelo_id: modelo.id)
      via_join_ids = modelo.vinculated_arquivos.where(client_id: @client.id).select(:id)
      @arquivos_by_modelo[modelo] = direct.or(Arquivo.where(id: via_join_ids))
                                        .includes(approved_version: :image_metadata)
                                        .order(created_at: :desc)
                                        .limit(20)
    end
  end

  def search
    clients = Client.search(params[:q]).limit(10)
    render json: clients.map { |c| { id: c.id, name: c.name, responsible: c.responsible } }
  end

  def create
    existing = Client.where("LOWER(name) = ?", client_params[:name].downcase).first
    if existing
      assign_client_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, alert: "Client \"#{existing.name}\" already exists."
      return
    end

    @client = Client.new(client_params)
    if @client.save
      assign_client_to_arquivo(@client) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, notice: "Client registered."
    else
      redirect_back fallback_location: arquivos_path, alert: @client.errors.full_messages.join(", ")
    end
  end

  def update
    if @client.update(client_params)
      redirect_back fallback_location: arquivos_path, notice: "Client updated."
    else
      redirect_back fallback_location: arquivos_path, alert: @client.errors.full_messages.join(", ")
    end
  end

  def destroy
    @client.destroy
    redirect_back fallback_location: arquivos_path, notice: "Client deleted."
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :responsible)
  end

  def assign_client_to_arquivo(client)
    arquivo = Arquivo.find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(client_id: client.id)
  end
end
