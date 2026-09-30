class MoldesController < ApplicationController
  exige :catalogo, :ver, only: %i[index show search for_client]
  exige :catalogo, :editar, only: %i[create update update_peca_config]
  exige :catalogo, :excluir, only: :destroy
  before_action :set_molde, only: %i[show update destroy update_peca_config]

  def index
    @moldes = Molde.ativos.left_joins(:arquivos)
                      .includes(:client, :modelo)
                      .select(Molde.arel_table[Arel.star], Arquivo.contagem_ativos(as: "arquivos_count"))
                      .group(:id)
                      .order(:nome)
    # Active clients plus a listed molde's own client even if trashed: the
    # edit dialog's required select had no option for it, so saving that
    # molde was silently blocked by the browser (29/09/2026).
    # Trashed ones last, and only while editing (data-somente-edicao, see
    # dialog_controller.js): a new molde can't be created for them.
    @clientes_para_escolher = Client.ativos.or(Client.where(id: @moldes.map(&:client_id)))
                                    .order(Arel.sql("deleted_at IS NOT NULL"), :name)
  end

  def show
    if @molde.modelo_id.present?
      @molde.sync_molde_pecas! if @molde.molde_pecas.empty?

      via_join_ids = @molde.vinculated_arquivos.ativos.where(organized: true, modelo_id: @molde.modelo_id, client_id: @molde.client_id).select(:id)
      @organized_arquivos = Arquivo.ativos.where(organized: true, modelo_id: @molde.modelo_id, molde_id: @molde.id, client_id: @molde.client_id)
                               .or(Arquivo.where(id: via_join_ids))
                               .includes(:peca, :tamanhos, approved_version: :image_metadata)
                               .order(:peca_id)
      @grouped_by_peca = @organized_arquivos.group_by(&:peca)

      @molde_pecas = @molde.molde_pecas.includes(:peca).order("pecas.nome")
      organized = @organized_arquivos
      @molde_pecas.each do |mp|
        mp.define_singleton_method(:corte_arquivo) do
          organized.find { |a| a.peca_id == mp.peca_id }
        end
      end
    else
      @organized_arquivos = []
      @grouped_by_peca = {}
      @molde_pecas = []
    end
  end

  def update_peca_config
    mp = @molde.molde_pecas.por_uuid!(params[:molde_peca_uuid])
    mp.update!(needs_cut: params[:needs_cut] == "true")

    redirect_to molde_path(@molde), notice: "Piece configuration updated."
  end

  def search
    moldes = Molde.ativos.search(params[:q]).limit(10)
    render json: moldes.map { |m| { id: m.uuid, nome: m.nome, client_name: m.client.name } }
  end

  def for_client
    moldes = Molde.ativos.where(client: Client.where(uuid: params[:client_uuid])).includes(:modelo).search(params[:q]).order(:nome)
    render json: moldes.map { |m| { id: m.uuid, nome: m.nome, modelo_uuid: m.modelo&.uuid } }
  end

  def create
    existing = Molde.where(client: Client.where(uuid: molde_params[:client_uuid]))
                     .where("LOWER(nome) = ?", molde_params[:nome].downcase).first
    if existing&.excluido?
      return redirect_back fallback_location: arquivos_path, alert: existing.aviso_na_lixeira
    end
    if existing
      assign_molde_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, alert: "Molde \"#{existing.nome}\" already exists for this client."
      return
    end

    @molde = Molde.new(molde_params)
    if @molde.save
      @molde.sync_molde_pecas! if @molde.modelo_id.present?
      assign_molde_to_arquivo(@molde) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, notice: "Molde registered."
    else
      redirect_back fallback_location: arquivos_path, alert: @molde.errors.full_messages.join(", ")
    end
  end

  def update
    modelo_anterior = @molde.modelo_id

    if @molde.update(molde_params)
      modelo_changed = @molde.modelo_id != modelo_anterior
      @molde.sync_molde_pecas! if modelo_changed && @molde.modelo_id.present?
      redirect_back fallback_location: arquivos_path, notice: "Molde updated."
    else
      redirect_back fallback_location: arquivos_path, alert: @molde.errors.full_messages.join(", ")
    end
  end

  def destroy
    @molde.excluir!(**autoria)
    redirect_back fallback_location: arquivos_path, notice: "Molde moved to the trash."
  end

  private

  def set_molde
    @molde = Molde.por_uuid!(params[:id])
  end

  def molde_params
    params.require(:molde).permit(:nome, :client_uuid, :modelo_uuid)
  end

  def assign_molde_to_arquivo(molde)
    arquivo = Arquivo.find_by(uuid: params[:arquivo_uuid])
    return unless arquivo

    if arquivo.corte?
      arquivo.moldes << molde unless arquivo.moldes.include?(molde)
    else
      arquivo.update(molde_id: molde.id)
    end
  end
end
