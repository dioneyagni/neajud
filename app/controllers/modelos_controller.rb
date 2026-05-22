class ModelosController < ApplicationController
  before_action :set_modelo, only: %i[update destroy]

  def index
    @modelos = Modelo.includes(:client).order(:nome)
  end

  def search
    modelos = Modelo.search(params[:q]).limit(10)
    render json: modelos.map { |m| { id: m.id, nome: m.nome, client_name: m.client.name } }
  end

  def for_client
    modelos = Modelo.where(client_id: params[:client_id]).order(:nome)
    render json: modelos.map { |m| { id: m.id, nome: m.nome } }
  end

  def create
    existing = Modelo.where("LOWER(nome) = ? AND client_id = ?", modelo_params[:nome].downcase, modelo_params[:client_id]).first
    if existing
      assign_modelo_to_stamp(existing) if params[:stamp_uuid].present?
      redirect_back fallback_location: stamps_path, alert: "Modelo \"#{existing.nome}\" already exists for this client."
      return
    end

    @modelo = Modelo.new(modelo_params)
    if @modelo.save
      assign_modelo_to_stamp(@modelo) if params[:stamp_uuid].present?
      redirect_back fallback_location: stamps_path, notice: "Modelo registered."
    else
      redirect_back fallback_location: stamps_path, alert: @modelo.errors.full_messages.join(", ")
    end
  end

  def update
    if @modelo.update(modelo_params)
      redirect_back fallback_location: stamps_path, notice: "Modelo updated."
    else
      redirect_back fallback_location: stamps_path, alert: @modelo.errors.full_messages.join(", ")
    end
  end

  def destroy
    @modelo.destroy
    redirect_back fallback_location: stamps_path, notice: "Modelo deleted."
  end

  private

  def set_modelo
    @modelo = Modelo.find(params[:id])
  end

  def modelo_params
    params.require(:modelo).permit(:nome, :client_id)
  end

  def assign_modelo_to_stamp(modelo)
    stamp = Stamp.find_by(uuid: params[:stamp_uuid])
    stamp&.update(modelo_id: modelo.id)
  end
end
