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
      assign_peca_to_stamp(existing) if params[:stamp_uuid].present?
      redirect_back fallback_location: stamps_path, alert: "Piece \"#{existing.nome}\" already exists."
      return
    end

    @peca = Peca.new(peca_params)
    if @peca.save
      assign_peca_to_stamp(@peca) if params[:stamp_uuid].present?
      redirect_back fallback_location: stamps_path, notice: "Piece registered."
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

  def assign_peca_to_stamp(peca)
    stamp = Stamp.find_by(uuid: params[:stamp_uuid])
    stamp&.update(peca_id: peca.id)
  end

  def peca_params
    params.require(:peca).permit(:nome)
  end
end
