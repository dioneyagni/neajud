class ModelosController < ApplicationController
  before_action :set_modelo, only: %i[show update destroy]

  def index
    @modelos = Modelo.includes(:client, :molde).order(:nome)
  end

  def show
    if @modelo.molde_id.present?
      @organized_arquivos = Arquivo.where(organized: true, molde_id: @modelo.molde_id, modelo_id: @modelo.id, client_id: @modelo.client_id)
                               .includes(:peca, :tamanhos, approved_version: :image_metadata)
                               .order(:peca_id)
      @grouped_by_peca = @organized_arquivos.group_by(&:peca)
    else
      @organized_arquivos = []
      @grouped_by_peca = {}
    end
  end

  def search
    modelos = Modelo.search(params[:q]).limit(10)
    render json: modelos.map { |m| { id: m.id, nome: m.nome, client_name: m.client.name } }
  end

  def for_client
    modelos = Modelo.where(client_id: params[:client_id]).order(:nome)
    render json: modelos.map { |m| { id: m.id, nome: m.nome, molde_id: m.molde_id } }
  end

  def create
    existing = Modelo.where("LOWER(nome) = ? AND client_id = ?", modelo_params[:nome].downcase, modelo_params[:client_id]).first
    if existing
      assign_modelo_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, alert: "Modelo \"#{existing.nome}\" already exists for this client."
      return
    end

    @modelo = Modelo.new(modelo_params)
    if @modelo.save
      assign_modelo_to_arquivo(@modelo) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, notice: "Modelo registered."
    else
      redirect_back fallback_location: arquivos_path, alert: @modelo.errors.full_messages.join(", ")
    end
  end

  def update
    if @modelo.update(modelo_params)
      redirect_back fallback_location: arquivos_path, notice: "Modelo updated."
    else
      redirect_back fallback_location: arquivos_path, alert: @modelo.errors.full_messages.join(", ")
    end
  end

  def destroy
    @modelo.destroy
    redirect_back fallback_location: arquivos_path, notice: "Modelo deleted."
  end

  private

  def set_modelo
    @modelo = Modelo.find(params[:id])
  end

  def modelo_params
    params.require(:modelo).permit(:nome, :client_id, :molde_id)
  end

  def assign_modelo_to_arquivo(modelo)
    arquivo = Arquivo.find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(modelo_id: modelo.id)
  end
end
