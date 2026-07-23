class MoldesController < ApplicationController
  before_action :set_molde, only: %i[show edit update destroy pecas]

  def index
    @moldes = Molde.left_joins(:arquivos)
                    .includes(:pecas)
                    .select("moldes.*, COUNT(DISTINCT arquivos.id) AS arquivos_count")
                    .group(:id)
                    .order(:nome)
  end

  def show
    @arquivos = @molde.arquivos.includes(approved_version: :image_metadata).order(created_at: :desc)
  end

  def new
    @molde = Molde.new
    @pecas = Peca.order(:nome)
  end

  def edit
    @pecas = Peca.order(:nome)
  end

  def pecas
    render json: @molde.pecas.order(:nome).map { |p| { id: p.id, nome: p.nome } }
  end

  def search
    moldes = Molde.search(params[:q]).limit(10)
    render json: moldes.map { |m| { id: m.id, nome: m.nome } }
  end

  def create
    existing = Molde.where("LOWER(nome) = ?", molde_params[:nome].downcase).first
    if existing
      assign_molde_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_to moldes_path, alert: "Molde \"#{existing.nome}\" already exists."
      return
    end

    @molde = Molde.new(molde_params)
    if @molde.save
      @molde.peca_ids = params[:molde][:peca_ids].reject(&:blank?) if params[:molde][:peca_ids]
      assign_molde_to_arquivo(@molde) if params[:arquivo_uuid].present?
      redirect_to molde_path(@molde), notice: "Molde registered."
    else
      @pecas = Peca.order(:nome)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @molde.update(molde_params)
      @molde.peca_ids = params[:molde][:peca_ids].reject(&:blank?) if params[:molde][:peca_ids]
      redirect_to molde_path(@molde), notice: "Molde updated."
    else
      @pecas = Peca.order(:nome)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @molde.destroy
    redirect_to moldes_path, notice: "Molde deleted."
  end

  private

  def set_molde
    @molde = Molde.find(params[:id])
  end

  def molde_params
    params.require(:molde).permit(:nome, peca_ids: [])
  end

  def assign_molde_to_arquivo(molde)
    arquivo = Arquivo.find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(molde_id: molde.id)
  end
end
