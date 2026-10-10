class ClientsController < ApplicationController
  exige :clientes, :ver, only: %i[index show search]
  exige :clientes, :editar, only: %i[create update]
  exige :clientes, :excluir, only: :destroy
  before_action :set_client, only: %i[show update destroy]

  def index
    @clients = visiveis(Client).ativos.left_joins(:moldes, :arquivos)
                     .select(Client.arel_table[Arel.star], visiveis(Molde).contagem_ativos(as: "moldes_count"), visiveis(Arquivo).contagem_ativos(as: "arquivos_count"))
                     .group(:id)
                     .order(:name)
  end

  def show
    @moldes = @client.moldes.ativos.order(:nome)
    @arquivos_by_molde = {}
    @moldes.each do |molde|
      direct = visiveis(Arquivo).ativos.where(client_id: @client.id, molde_id: molde.id, category: "artes")
      via_join_ids = molde.vinculated_arquivos.ativos.where(client_id: @client.id, category: "artes").select(:id)
      @arquivos_by_molde[molde] = direct.or(visiveis(Arquivo).where(id: via_join_ids))
                                        .includes(approved_version: :image_metadata)
                                        .order(created_at: :desc)
                                        .limit(20)
    end
    @cortes_por_molde = @moldes.to_h { |molde| [ molde, visiveis(Arquivo).cortes_ligados_ao_molde(molde).includes(approved_version: :image_metadata).order(:filename) ] }
    @cortes_pendentes = visiveis(Arquivo).cortes_pendentes_do_cliente(@client).includes(approved_version: :image_metadata).order(created_at: :desc)

    @client_materiais = MateriaPrima
      .joins(:movimento_estoques)
      .where(movimento_estoques: { client_id: @client.id })
      .includes(:grupo_material, :cor_material)
      .distinct
      .order(:largura)

    @client_saldos = compute_client_saldos
  end

  def search
    clients = visiveis(Client).ativos.search(params[:q]).limit(10)
    render json: clients.map { |c| { id: c.uuid, name: c.name, responsible: c.responsible } }
  end

  def create
    existing = visiveis(Client).where("LOWER(name) = ?", client_params[:name].downcase).first
    if existing&.excluido?
      return redirect_back fallback_location: arquivos_path, alert: existing.aviso_na_lixeira
    end
    if existing
      assign_client_to_arquivo(existing) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, alert: "Client \"#{existing.name}\" already exists."
      return
    end

    @client = visiveis(Client).new(client_params)
    if @client.save
      assign_client_to_arquivo(@client) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, notice: "Client registered."
    else
      redirect_back fallback_location: arquivos_path, alert: @client.errors.full_messages.join(", ")
    end
  end

  def update
    if @client.update(client_params)
      redirect_back fallback_location: arquivos_path, notice: "Client updated."
    else
      redirect_back fallback_location: arquivos_path, alert: @client.errors.full_messages.join(", ")
    end
  end

  def destroy
    @client.excluir!(**autoria)
    redirect_back fallback_location: arquivos_path, notice: "Client moved to the trash."
  end

  private

  def set_client
    @client = visiveis(Client).por_uuid!(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :responsible)
  end

  def assign_client_to_arquivo(client)
    arquivo = visiveis(Arquivo).find_by(uuid: params[:arquivo_uuid])
    arquivo&.update(client_id: client.id)
  end

  def compute_client_saldos
    data = @client.movimento_estoques.group(:materia_prima_id).select(
      "materia_prima_id",
      "SUM(CASE WHEN tipo = 'entrada' THEN quantidade ELSE 0 END) AS total_in",
      "SUM(CASE WHEN tipo = 'saida' THEN quantidade ELSE 0 END) AS total_out"
    )
    data.each_with_object({}) do |row, hash|
      hash[row.materia_prima_id] = row.total_in.to_f - row.total_out.to_f
    end
  end
end
