class PecasController < ApplicationController
  before_action :set_peca, only: %i[edit update destroy]

  def index
    @pecas = Peca.ativos.left_joins(:arquivos)
                  .includes(:moldes)
                  .select(Peca.arel_table[Arel.star], Arquivo.contagem_ativos(as: "arquivos_count"))
                  .group(:id)
                  .order(:nome)
  end

  def new
    @peca = Peca.new
    @molde_id = params[:molde_id]
  end

  def search
    pecas = Peca.ativos.search(params[:q]).limit(10)
    render json: pecas.map { |p| { id: p.id, nome: p.nome } }
  end

  def for_cascade
    scope = Arquivo.ativos.where(organized: true, molde_id: params[:molde_id])
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    peca_ids = scope.distinct.pluck(:peca_id)
    pecas = Peca.ativos.where(id: peca_ids).order(:nome)
    render json: pecas.map { |p| { id: p.id, nome: p.nome } }
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
      if params[:molde_id].present?
        Molde.ativos.find(params[:molde_id]).pecas << @peca
        redirect_to edit_molde_path(params[:molde_id]), notice: "Peça added to molde."
      else
        redirect_to pecas_path, notice: "Piece registered."
      end
    else
      @molde_id = params[:molde_id]
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
