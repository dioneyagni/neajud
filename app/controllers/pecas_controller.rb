class PecasController < ApplicationController
  before_action :set_peca, only: %i[update destroy]

  def index
    @pecas = Peca.order(:nome)
  end

  def search
    pecas = Peca.search(params[:q]).limit(10)
    render json: pecas.map { |p| { id: p.id, nome: p.nome } }
  end

  def create
    existing = Peca.where("LOWER(nome) = ?", peca_params[:nome].downcase).first
    if existing
      redirect_back fallback_location: stamps_path, alert: "Peca \"#{existing.nome}\" already exists."
      return
    end

    @peca = Peca.new(peca_params)
    if @peca.save
      redirect_back fallback_location: stamps_path, notice: "Peca registered."
    else
      redirect_back fallback_location: stamps_path, alert: @peca.errors.full_messages.join(", ")
    end
  end

  def update
    if @peca.update(peca_params)
      redirect_back fallback_location: stamps_path, notice: "Peca updated."
    else
      redirect_back fallback_location: stamps_path, alert: @peca.errors.full_messages.join(", ")
    end
  end

  def destroy
    @peca.destroy
    redirect_back fallback_location: stamps_path, notice: "Peca deleted."
  end

  private

  def set_peca
    @peca = Peca.find(params[:id])
  end

  def peca_params
    params.require(:peca).permit(:nome)
  end
end
