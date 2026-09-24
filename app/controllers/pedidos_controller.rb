class PedidosController < ApplicationController
  before_action :set_pedido, only: %i[show update destroy remover_item confirmar resumo atualizar_item alternar_peca producao]

  def index
    @pedidos = Pedido.left_joins(:itens_pedido)
                      .includes(:client)
                      .select("pedidos.*, COUNT(DISTINCT itens_pedido.id) AS itens_count")
                      .group(:id)
                      .order(created_at: :desc)
    @pendentes_por_pedido = ItemPedidoPeca.pendentes.joins(:item_pedido).group("itens_pedido.pedido_id").count
  end

  def show
    @pedido = Pedido.includes(itens_pedido: {
      arquivo: [ :client, :tamanhos, { tamanho: :arquivo }, { modelo: :molde }, approved_version: :image_metadata ],
      materia_prima: :grupo_material,
      item_pedido_pecas: [ :peca, { arquivo: :approved_version } ]
    }).find_by!(uuid: params[:uuid])
  end

  def create
    @pedido = Pedido.create!(status: "rascunho")
    session[:current_pedido_uuid] = @pedido.uuid
    redirect_to resumo_pedido_path(@pedido)
  end

  def update
    if @pedido.update(pedido_params)
      redirect_to resumo_pedido_path(@pedido), notice: "Pedido updated."
    else
      redirect_to resumo_pedido_path(@pedido), alert: "Could not update."
    end
  end

  def destroy
    @pedido.destroy!
    session.delete(:current_pedido_uuid) if session[:current_pedido_uuid] == @pedido.uuid
    redirect_to pedidos_path, notice: "Pedido removed."
  end

  def adicionar_item
    arquivo = Arquivo.find_by!(uuid: params[:arquivo_uuid])

    @pedido = if arquivo.client_id
      Pedido.find_by(client_id: arquivo.client_id, status: "rascunho") ||
        Pedido.create!(status: "rascunho", client_id: arquivo.client_id)
    else
      Pedido.find_by(uuid: session[:current_pedido_uuid]) ||
        Pedido.create!(status: "rascunho")
    end
    session[:current_pedido_uuid] = @pedido.uuid

    materia_prima = MateriaPrima.find_by(id: params[:materia_prima_id]) if params[:materia_prima_id].present?

    ItemPedido.transaction do
      item = @pedido.itens_pedido.create!(arquivo: arquivo, materia_prima: materia_prima)
      item.compor_pecas!(ModeloComposicaoService.call(arquivo))
      item.excluir_pecas!(params[:excluir_arquivos])

      grade_params = params[:grade]
      if grade_params.respond_to?(:each)
        grade_params.each do |tamanho_nome, quantidade|
          qtd = quantidade.to_i
          item.grades.create!(tamanho_nome: tamanho_nome, quantidade: qtd) if qtd > 0
        end
      end
    end

    render json: { ok: true, pedido_uuid: @pedido.uuid, total_itens: @pedido.total_itens }
  rescue ActiveRecord::RecordNotFound => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  def remover_item
    @pedido.itens_pedido.find_by!(uuid: params[:id]).destroy!
    redirect_to resumo_pedido_path(@pedido), notice: "Item removed."
  end

  def confirmar
    unless @pedido.status == "rascunho"
      return redirect_to pedidos_path, alert: "Pedido already confirmed."
    end

    pendentes = @pedido.pecas_pendentes.to_a
    if pendentes.any?
      return redirect_to resumo_pedido_path(@pedido), alert: pendentes_alert(pendentes)
    end

    items_by_client = @pedido.itens_pedido.includes(:arquivo).group_by { |i| i.arquivo.client_id }

    if items_by_client.size == 1
      client_id = items_by_client.keys.first
      @pedido.update!(status: "confirmado", client_id: client_id)
      session.delete(:current_pedido_uuid) if session[:current_pedido_uuid] == @pedido.uuid
      redirect_to pedidos_path, notice: "Pedido confirmed."
      return
    end

    items_by_client.each do |client_id, itens|
      novo = Pedido.create!(client_id: client_id, status: "confirmado")
      itens.each do |item|
        novo_item = novo.itens_pedido.create!(
          arquivo: item.arquivo,
          materia_prima: item.materia_prima
        )
        item.grades.each do |g|
          novo_item.grades.create!(tamanho_nome: g.tamanho_nome, quantidade: g.quantidade)
        end
        novo_item.copiar_pecas_de!(item)
      end
    end

    @pedido.update!(status: "cancelado")
    session.delete(:current_pedido_uuid) if session[:current_pedido_uuid] == @pedido.uuid

    redirect_to pedidos_path, notice: "Pedido confirmed! #{items_by_client.size} order(s) created."
  end

  def atualizar_item
    item = @pedido.itens_pedido.find_by!(uuid: params[:id])
    grade_params = params[:grade]

    if grade_params.respond_to?(:each)
      grade_params.each do |tamanho_nome, quantidade|
        qtd = quantidade.to_i
        grade = item.grades.find_or_initialize_by(tamanho_nome: tamanho_nome)
        if qtd > 0
          grade.update!(quantidade: qtd)
        elsif grade.persisted?
          grade.destroy!
        end
      end
    end

    render json: { ok: true }
  rescue ActiveRecord::RecordNotFound
    render json: { ok: false, error: "Item not found" }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  # Checks/unchecks one piece of an item. Only while the pedido is a draft:
  # once confirmed, its pieces are what goes to production.
  # Usage: PATCH /pedidos/:uuid/alternar_peca?id=<item uuid>&peca_id=<row id>&incluida=false
  def alternar_peca
    error = alternar_peca_error
    return render json: { ok: false, error: error }, status: :unprocessable_content if error

    peca_row = @pedido.itens_pedido.find_by!(uuid: params[:id]).item_pedido_pecas.find(params[:peca_id])
    return render json: { ok: false, error: "Piece #{peca_row.id} has no arte (pending); it cannot be checked or unchecked" }, status: :unprocessable_content unless peca_row.arquivo

    peca_row.update!(incluida: params[:incluida] == "true")
    render json: { ok: true, estado: peca_row.estado }
  rescue ActiveRecord::RecordNotFound
    render json: { ok: false, error: "Item #{params[:id].inspect} or piece #{params[:peca_id].inspect} not found in pedido #{@pedido.uuid}" }, status: :not_found
  end

  # The "Produção" section alone, reloaded (Turbo Frame) when a piece is
  # checked/unchecked on the pedido page.
  def producao
    render partial: "producao", locals: { pedido: @pedido }
  end

  def resumo
    render :show
  end

  private

  # Names each pending piece and the arte of its item, so the user knows what to complete.
  def pendentes_alert(pendentes)
    lista = pendentes.map { |p| "#{p.peca&.nome || "Sem peça"} (item #{p.item_pedido.arquivo.filename})" }
    "Cannot confirm: #{pendentes.size} piece(s) without arte — #{lista.join(", ")}. Complete them first."
  end

  def alternar_peca_error
    return "Pedido is #{@pedido.status}; pieces can only change while it is rascunho" unless @pedido.status == "rascunho"
    return "incluida must be \"true\" or \"false\", got #{params[:incluida].inspect}" unless %w[true false].include?(params[:incluida])

    nil
  end

  def set_pedido
    @pedido = Pedido.find_by!(uuid: params[:uuid])
  end

  def pedido_params
    params.permit(:observacoes)
  end
end
