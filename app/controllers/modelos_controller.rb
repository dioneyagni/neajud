class ModelosController < ApplicationController
  before_action :set_modelo, only: %i[show update destroy update_peca_config]

  def index
    @modelos = Modelo.left_joins(:arquivos)
                      .includes(:client, :molde)
                      .select("modelos.*, COUNT(DISTINCT arquivos.id) AS arquivos_count")
                      .group(:id)
                      .order(:nome)
  end

  def show
    if @modelo.molde_id.present?
      @modelo.sync_modelo_pecas! if @modelo.modelo_pecas.empty?

      via_join_ids = @modelo.vinculated_arquivos.where(organized: true, molde_id: @modelo.molde_id, client_id: @modelo.client_id).select(:id)
      @organized_arquivos = Arquivo.where(organized: true, molde_id: @modelo.molde_id, modelo_id: @modelo.id, client_id: @modelo.client_id)
                               .or(Arquivo.where(id: via_join_ids))
                               .includes(:peca, :tamanhos, approved_version: :image_metadata)
                               .order(:peca_id)
      @grouped_by_peca = @organized_arquivos.group_by(&:peca)

      @modelo_pecas = @modelo.modelo_pecas.includes(:peca).order("pecas.nome")
      organized = @organized_arquivos
      @modelo_pecas.each do |mp|
        mp.define_singleton_method(:corte_arquivo) do
          organized.find { |a| a.peca_id == mp.peca_id }
        end
      end
    else
      @organized_arquivos = []
      @grouped_by_peca = {}
      @modelo_pecas = []
    end
  end

  def update_peca_config
    mp = @modelo.modelo_pecas.find(params[:modelo_peca_id])
    mp.update!(needs_cut: params[:needs_cut] == "true")

    redirect_to modelo_path(@modelo), notice: "Piece configuration updated."
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
      @modelo.sync_modelo_pecas! if @modelo.molde_id.present?
      assign_modelo_to_arquivo(@modelo) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, notice: "Modelo registered."
    else
      redirect_back fallback_location: arquivos_path, alert: @modelo.errors.full_messages.join(", ")
    end
  end

  def update
    molde_changed = @modelo.molde_id_changed? && @modelo.molde_id != modelo_params[:molde_id]

    if @modelo.update(modelo_params)
      @modelo.sync_modelo_pecas! if molde_changed && @modelo.molde_id.present?
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
    return unless arquivo

    if arquivo.corte?
      arquivo.modelos << modelo unless arquivo.modelos.include?(modelo)
    else
      arquivo.update(modelo_id: modelo.id)
    end
  end
end
