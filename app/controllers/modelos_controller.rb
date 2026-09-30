class ModelosController < ApplicationController
  exige :catalogo, :ver, only: %i[index show search pecas]
  exige :catalogo, :editar, only: %i[new create edit update]
  exige :catalogo, :excluir, only: :destroy
  before_action :set_modelo, only: %i[show edit update destroy pecas]

  def index
    @modelos = Modelo.ativos.left_joins(:arquivos)
                    .includes(:pecas)
                    .select(Modelo.arel_table[Arel.star], Arquivo.contagem_ativos(as: "arquivos_count"))
                    .group(:id)
                    .order(:nome)
  end

  def show
    @arquivos = @modelo.arquivos.ativos.includes(approved_version: :image_metadata).order(created_at: :desc)
  end

  def new
    @modelo = Modelo.new
    @pecas = pecas_para_escolher
  end

  def edit
    @pecas = pecas_para_escolher
  end

  def pecas
    render json: @modelo.pecas.ativos.order(:nome).map { |p| { id: p.uuid, nome: p.nome } }
  end

  def search
    modelos = Modelo.ativos.search(params[:q]).limit(10)
    render json: modelos.map { |m| { id: m.uuid, nome: m.nome } }
  end

  def create
    existing = Modelo.where("LOWER(nome) = ?", modelo_params[:nome].downcase).first
    if existing&.excluido?
      return redirect_to modelos_path, alert: existing.aviso_na_lixeira
    end
    if existing
      assign_modelo_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_to modelos_path, alert: "Modelo \"#{existing.nome}\" already exists."
      return
    end

    @modelo = Modelo.new(modelo_params)
    if @modelo.save
      atribuir_pecas
      assign_modelo_to_arquivo(@modelo) if params[:arquivo_uuid].present?
      redirect_to modelo_path(@modelo), notice: "Modelo registered."
    else
      @pecas = pecas_para_escolher
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @modelo.update(modelo_params)
      atribuir_pecas
      redirect_to modelo_path(@modelo), notice: "Modelo updated."
    else
      @pecas = pecas_para_escolher
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @modelo.excluir!(**autoria)
    redirect_to modelos_path, notice: "Modelo moved to the trash."
  end

  private

  def set_modelo
    @modelo = Modelo.por_uuid!(params[:id])
  end

  # Active peças, plus any trashed one this modelo already has: leaving it out
  # of the checkboxes would silently unlink it on save.
  def pecas_para_escolher
    Peca.ativos.or(Peca.where(id: @modelo&.peca_ids)).order(:nome)
  end

  def modelo_params
    params.require(:modelo).permit(:nome)
  end

  # The form lists the chosen peças by uuid; when none is sent the list is
  # left as it is (same as before the uuids, Etapa 1.1).
  def atribuir_pecas
    uuids = params.dig(:modelo, :peca_uuids)
    return unless uuids

    @modelo.pecas = Peca.where(uuid: Array(uuids).compact_blank)
  end

  def assign_modelo_to_arquivo(modelo)
    arquivo = Arquivo.find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(modelo_id: modelo.id)
  end
end
