class PecasController < ApplicationController
  exige :catalogo, :ver, only: %i[index search for_cascade]
  exige :catalogo, :editar, only: %i[new create edit update]
  exige :catalogo, :excluir, only: :destroy
  before_action :set_peca, only: %i[edit update destroy]

  def index
    @pecas = Peca.ativos.left_joins(:arquivos)
                  .includes(:modelos)
                  .select(Peca.arel_table[Arel.star], Arquivo.contagem_ativos(as: "arquivos_count"))
                  .group(:id)
                  .order(:nome)
  end

  def new
    @peca = Peca.new
    @modelo_uuid = params[:modelo_uuid]
  end

  def search
    pecas = Peca.ativos.search(params[:q]).limit(10)
    render json: pecas.map { |p| { id: p.uuid, nome: p.nome } }
  end

  def for_cascade
    scope = Arquivo.ativos.where(organized: true, modelo: Modelo.where(uuid: params[:modelo_uuid]))
    scope = scope.where(client: Client.where(uuid: params[:client_uuid])) if params[:client_uuid].present?
    peca_ids = scope.distinct.pluck(:peca_id)
    pecas = Peca.ativos.where(id: peca_ids).order(:nome)
    render json: pecas.map { |p| { id: p.uuid, nome: p.nome } }
  end

  def create
    existing = Peca.where("LOWER(nome) = ?", peca_params[:nome].downcase).first
    if existing&.excluido?
      return redirect_to pecas_path, alert: existing.aviso_na_lixeira
    end
    if existing
      assign_peca_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_to pecas_path, alert: "Piece \"#{existing.nome}\" already exists."
      return
    end

    @peca = Peca.new(peca_params)
    if @peca.save
      assign_peca_to_arquivo(@peca) if params[:arquivo_uuid].present?
      if params[:modelo_uuid].present?
        modelo = Modelo.ativos.por_uuid!(params[:modelo_uuid])
        modelo.pecas << @peca
        redirect_to edit_modelo_path(modelo), notice: "Peça added to modelo."
      else
        redirect_to pecas_path, notice: "Piece registered."
      end
    else
      @modelo_uuid = params[:modelo_uuid]
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @peca.update(peca_params)
      redirect_to pecas_path, notice: "Peca updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @peca.excluir!(**autoria)
    redirect_to pecas_path, notice: "Peca moved to the trash."
  end

  private

  def set_peca
    @peca = Peca.por_uuid!(params[:id])
  end

  def assign_peca_to_arquivo(peca)
    arquivo = Arquivo.find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(peca_id: peca.id)
  end

  def peca_params
    params.require(:peca).permit(:nome)
  end
end
