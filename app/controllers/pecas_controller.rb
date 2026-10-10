class PecasController < ApplicationController
  exige :catalogo, :ver, only: %i[index search for_cascade]
  exige :catalogo, :editar, only: %i[new create edit update]
  exige :catalogo, :excluir, only: :destroy
  before_action :set_peca, only: %i[edit update destroy]

  def index
    @pecas = visiveis(Peca).ativos.includes(:moldes).order(:nome)
    # Etapa 2.8: the molde names and file counts of the visible records only —
    # peca.moldes and a joined count would show every client's.
    @moldes_visiveis = visiveis(Molde).ativos.ids.to_set
    @arquivos_por_peca = visiveis(Arquivo).ativos.group(:peca_id).count
  end

  def new
    @peca = visiveis(Peca).new
    @molde_uuid = params[:molde_uuid]
  end

  def search
    pecas = visiveis(Peca).ativos.search(params[:q]).limit(10)
    render json: pecas.map { |p| { id: p.uuid, nome: p.nome } }
  end

  # The pieces of a molde's cortes, for the arte's Size Selection — the same
  # cortes the automatic search and the pedido use (Arquivo.cortes_do_molde).
  # Usage: GET /pecas/for_cascade.json?molde_uuid=… → [{ id: <uuid>, nome: }]
  def for_cascade
    molde = visiveis(Molde).find_by(uuid: params[:molde_uuid].to_s)
    peca_ids = visiveis(Arquivo).cortes_do_molde(molde).distinct.pluck(:peca_id)
    pecas = visiveis(Peca).ativos.where(id: peca_ids).order(:nome)
    render json: pecas.map { |p| { id: p.uuid, nome: p.nome } }
  end

  def create
    existing = visiveis(Peca).where("LOWER(nome) = ?", peca_params[:nome].downcase).first
    if existing&.excluido?
      return redirect_to pecas_path, alert: existing.aviso_na_lixeira
    end
    if existing
      assign_peca_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_to pecas_path, alert: "Piece \"#{existing.nome}\" already exists."
      return
    end

    @peca = visiveis(Peca).new(peca_params)
    if @peca.save
      assign_peca_to_arquivo(@peca) if params[:arquivo_uuid].present?
      # "Register new piece" from a molde's page: it becomes one of its parts
      # (Etapa 1.1, 3/5 — parts belong to the molde, not to the category).
      if params[:molde_uuid].present?
        molde = visiveis(Molde).ativos.por_uuid!(params[:molde_uuid])
        molde.molde_pecas.create!(peca: @peca)
        redirect_to molde_path(molde), notice: "Peça added to molde."
      else
        redirect_to pecas_path, notice: "Piece registered."
      end
    else
      @molde_uuid = params[:molde_uuid]
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
    @peca = visiveis(Peca).por_uuid!(params[:id])
  end

  def assign_peca_to_arquivo(peca)
    arquivo = visiveis(Arquivo).find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(peca_id: peca.id)
  end

  def peca_params
    params.require(:peca).permit(:nome)
  end
end
