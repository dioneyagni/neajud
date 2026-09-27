class MoldesController < ApplicationController
  exige :catalogo, :ver, only: %i[index show search pecas]
  exige :catalogo, :editar, only: %i[new create edit update]
  exige :catalogo, :excluir, only: :destroy
  before_action :set_molde, only: %i[show edit update destroy pecas]

  def index
    @moldes = Molde.ativos.left_joins(:arquivos)
                    .includes(:pecas)
                    .select(Molde.arel_table[Arel.star], Arquivo.contagem_ativos(as: "arquivos_count"))
                    .group(:id)
                    .order(:nome)
  end

  def show
    @arquivos = @molde.arquivos.ativos.includes(approved_version: :image_metadata).order(created_at: :desc)
  end

  def new
    @molde = Molde.new
    @pecas = pecas_para_escolher
  end

  def edit
    @pecas = pecas_para_escolher
  end

  def pecas
    render json: @molde.pecas.ativos.order(:nome).map { |p| { id: p.id, nome: p.nome } }
  end

  def search
    moldes = Molde.ativos.search(params[:q]).limit(10)
    render json: moldes.map { |m| { id: m.id, nome: m.nome } }
  end

  def create
    existing = Molde.where("LOWER(nome) = ?", molde_params[:nome].downcase).first
    if existing&.excluido?
      return redirect_to moldes_path, alert: existing.aviso_na_lixeira
    end
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
      @pecas = pecas_para_escolher
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @molde.update(molde_params)
      @molde.peca_ids = params[:molde][:peca_ids].reject(&:blank?) if params[:molde][:peca_ids]
      redirect_to molde_path(@molde), notice: "Molde updated."
    else
      @pecas = pecas_para_escolher
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @molde.excluir!(**autoria)
    redirect_to moldes_path, notice: "Molde moved to the trash."
  end

  private

  def set_molde
    @molde = Molde.find(params[:id])
  end

  # Active peças, plus any trashed one this molde already has: leaving it out
  # of the checkboxes would silently unlink it on save.
  def pecas_para_escolher
    Peca.ativos.or(Peca.where(id: @molde&.peca_ids)).order(:nome)
  end

  def molde_params
    params.require(:molde).permit(:nome, peca_ids: [])
  end

  def assign_molde_to_arquivo(molde)
    arquivo = Arquivo.find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(molde_id: molde.id)
  end
end
