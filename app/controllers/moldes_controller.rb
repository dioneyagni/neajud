class MoldesController < ApplicationController
  CAMPOS_EDITAVEIS = %i[sufixo modelo_uuid tamanho_inicial tamanho_final].freeze

  exige :catalogo, :ver, only: %i[index show search for_client]
  exige :catalogo, :editar, only: %i[create update update_peca_config adicionar_parte remover_parte]
  exige :catalogo, :excluir, only: :destroy
  before_action :set_molde, only: %i[show update destroy update_peca_config adicionar_parte remover_parte]

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
    @organized_arquivos = cortes_organizados
    @molde_pecas = @molde.molde_pecas.includes(:peca).order("pecas.nome")
    @pecas_para_adicionar = Peca.ativos.where.not(id: @molde.molde_pecas.select(:peca_id)).order(:nome)
    organized = @organized_arquivos.to_a
    @molde_pecas.each do |mp|
      mp.define_singleton_method(:corte_arquivo) do
        organized.find { |a| a.peca_id == mp.peca_id }
      end
    end
  end

  # Parts belong to the molde (Etapa 1.1, 3/5): chosen here from the company's
  # piece list, each with "corta / não corta".
  # Usage: POST /moldes/:uuid/adicionar_parte (peca_uuid)
  def adicionar_parte
    peca = Peca.ativos.por_uuid!(params[:peca_uuid])
    parte = @molde.molde_pecas.create(peca: peca)
    return redirect_to molde_path(@molde), notice: "Part \"#{peca.nome}\" added." if parte.persisted?

    redirect_to molde_path(@molde), alert: "Could not add \"#{peca.nome}\": #{parte.errors.full_messages.to_sentence}"
  end

  # Physical on purpose, like unlinking a corte: the part row is configuration
  # of this molde, not something a user registered.
  # Usage: DELETE /moldes/:uuid/remover_parte (molde_peca_uuid)
  def remover_parte
    parte = @molde.molde_pecas.por_uuid!(params[:molde_peca_uuid])
    parte.destroy!
    redirect_to molde_path(@molde), notice: "Part \"#{parte.peca.nome}\" removed."
  end

  def update_peca_config
    mp = @molde.molde_pecas.por_uuid!(params[:molde_peca_uuid])
    mp.update!(needs_cut: params[:needs_cut] == "true")

    redirect_to molde_path(@molde), notice: "Piece configuration updated."
  end

  def search
    moldes = Molde.ativos.search(params[:q]).limit(10)
    render json: moldes.map { |m| { id: m.uuid, nome: m.nome, codigo: m.codigo, sufixo: m.sufixo, client_name: m.client.name } }
  end

  def for_client
    moldes = Molde.ativos.where(client: Client.where(uuid: params[:client_uuid])).includes(:modelo).search(params[:q]).order(:nome)
    render json: moldes.map { |m| { id: m.uuid, nome: m.nome, codigo: m.codigo, sufixo: m.sufixo, modelo_uuid: m.modelo&.uuid } }
  end

  # No duplicate-name check any more (Etapa 1.1, 4/5): the number makes every
  # name unique in the client.
  def create
    @molde = Molde.new(params.require(:molde).permit(*CAMPOS_EDITAVEIS, :client_uuid, :variacao_de_uuid))
    if @molde.save
      assign_molde_to_arquivo(@molde) if params[:arquivo_uuid].present?
      redirect_back fallback_location: arquivos_path, notice: "Molde #{@molde.nome} registered."
    else
      redirect_back fallback_location: arquivos_path, alert: @molde.errors.full_messages.join(", ")
    end
  end

  # The client and the base are fixed once created (their fields aren't read).
  def update
    if @molde.update(params.require(:molde).permit(*CAMPOS_EDITAVEIS))
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


  # The cortes of this molde's category and client, plus those linked to it
  # directly (a corte serves several moldes).
  def cortes_organizados
    via_ligacao = @molde.vinculated_arquivos.ativos.where(organized: true, modelo_id: @molde.modelo_id, client_id: @molde.client_id).select(:id)
    proprios = Arquivo.ativos.where(organized: true, modelo_id: @molde.modelo_id, molde_id: @molde.id, client_id: @molde.client_id)
    proprios.or(Arquivo.where(id: via_ligacao)).includes(:peca, :tamanhos, approved_version: :image_metadata).order(:peca_id)
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
