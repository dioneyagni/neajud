class PecasController < ApplicationController
  before_action :set_peca, only: %i[update destroy]

  def index
    @pecas = Peca.order(:nome)
  end

  def search
    pecas = Peca.search(params[:q]).limit(10)
    render json: pecas.map { |p| { id: p.id, nome: p.nome } }
  end

  def for_cascade
    scope = Arquivo.where(organized: true, molde_id: params[:molde_id])
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    peca_ids = scope.distinct.pluck(:peca_id)
    pecas = Peca.where(id: peca_ids).order(:nome)
    render json: pecas.map { |p| { id: p.id, nome: p.nome } }
  end

  def create
    existing = Peca.where("LOWER(nome) = ?", peca_params[:nome].downcase).first
    if existing
      assign_peca_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, alert: "Piece \"#{existing.nome}\" already exists."
      return
    end

    @peca = Peca.new(peca_params)
    if @peca.save
      assign_peca_to_arquivo(@peca) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, notice: "Piece registered."
    else
      redirect_back fallback_location: arquivos_path, alert: @peca.errors.full_messages.join(", ")
    end
  end

  def update
    if @peca.update(peca_params)
      redirect_back fallback_location: arquivos_path, notice: "Peca updated."
    else
      redirect_back fallback_location: arquivos_path, alert: @peca.errors.full_messages.join(", ")
    end
  end

  def destroy
    @peca.destroy
    redirect_back fallback_location: arquivos_path, notice: "Peca deleted."
  end

  private

  def set_peca
    @peca = Peca.find(params[:id])
  end

  def assign_peca_to_arquivo(peca)
    arquivo = Arquivo.find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(peca_id: peca.id)
  end

  def peca_params
    params.require(:peca).permit(:nome)
  end
end
