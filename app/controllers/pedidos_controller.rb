class PedidosController < ApplicationController
  include NumeroDigitado
  include ConfirmacaoDoPedido
  exige :pedidos, :ver, only: %i[index show resumo corte impressao etapa]
  exige_acao :baixar_producao, only: %i[baixar_corte baixar_impressao]
  # Etapa 2.8 (3a): the Corte page is the cortes' (DXF drawings).
  exige_aberto :cortes, only: :corte
  exige_acao :atualizar_producao, only: %i[entregar gerar_reposicao]
  exige :pedidos, :editar, only: %i[create update adicionar_item remover_item atualizar_item alternar_peca confirmar artes_para_adicionar]
  exige :pedidos, :excluir, only: :destroy
  # Etapa 2.8 (5/5): the client sends his draft (EnviosPedidoController); the
  # factory confirms it.
  exige_equipe only: :confirmar
  before_action :set_pedido, only: %i[show update destroy remover_item confirmar resumo atualizar_item alternar_peca corte baixar_corte impressao baixar_impressao etapa entregar gerar_reposicao]
  before_action :recusar_pedido_excluido, only: %i[update destroy remover_item confirmar atualizar_item alternar_peca]
  before_action :recusar_pedido_travado, only: %i[update remover_item atualizar_item alternar_peca]
  # Etapa 2.7c: a tecido pedido's stages share one page of their own.
  before_action :levar_tecido_a_producao, only: %i[corte baixar_corte impressao baixar_impressao etapa]

  # Etapa 2.2 (3/3): filtered by status (?status=em_producao), each pedido
  # past the draft with its stages' progress; Etapa 2.3d2: or by waiting for
  # material (?aguardando=1).
  def index
    @status = params[:status] if Pedido::STATUS.include?(params[:status])
    @pedidos = visiveis(Pedido).ativos.left_joins(:itens_pedido)
                      .includes(:client)
                      .select("pedidos.*, COUNT(DISTINCT itens_pedido.id) AS itens_count")
                      .group(:id)
                      .order(created_at: :desc)
    @pedidos = @pedidos.where(status: @status) if @status
    # Etapa 2.3d2: ?aguardando=1 — the pedidos waiting for material.
    @aguardando = params[:aguardando] == "1"
    @pedidos = @pedidos.where(id: (@aguardando_material = AguardandoMaterial.call).pedido_ids) if @aguardando
    # Only drafts (and those sent to the factory) can be confirmed; there are few at a time.
    @bloqueios_por_pedido = @pedidos.select(&:confirmavel?).to_h { |p| [ p.id, p.bloqueios_confirmacao.size ] }
    # Etapa 2.8 (5/5): the client's drafts the factory returned, on top with their note.
    @devolvidos = cliente_final? ? visiveis(Pedido).ativos.rascunhos.filter_map(&:devolucao_pendente) : []
  end

  def show
    @pedido = visiveis(Pedido).includes(itens_pedido: {
      arquivo: [ :client, :tamanhos, { tamanho: :arquivo }, { molde: :modelo }, approved_version: :image_metadata ],
      materia_prima: :grupo_material,
      item_pedido_pecas: :peca
    }).find_by!(uuid: params[:uuid])
  end

  def create
    @pedido = visiveis(Pedido).create!(status: "rascunho")
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
    @pedido.excluir!(**autoria)
    session.delete(:current_pedido_uuid) if session[:current_pedido_uuid] == @pedido.uuid
    redirect_to pedidos_path, notice: "Pedido moved to the trash."
  end

  def adicionar_item
    # Etapa 2.6b1 (D4): an etiqueta of the coleção geral is ordered by whoever
    # reads it — only to add it, into his own pedido (visiveis(Pedido) below).
    arquivo = visiveis(Arquivo, colecao_geral: true).ativos.find_by!(uuid: params[:arquivo_uuid])
    tipo = Pedido.tipo_para(arquivo.arte)
    # Checked before touching anything, so a zero add doesn't even create a draft.
    erro = erro_da_quantidade(tipo) || erro_de_grade(arquivo.arte, params[:grade])
    return render json: { ok: false, error: erro }, status: :unprocessable_content if erro

    materia_prima = material_do_item(arquivo, tipo)
    @pedido = pedido_de_destino(arquivo, tipo)
    return render json: { ok: false, error: "#{@pedido.rotulo_lixeira} can't take items: expected a draft, got #{situacao_do_pedido}" }, status: :unprocessable_content unless @pedido.editavel?(cliente_final: cliente_final?)
    # Decided 13/10/2026: the pedido's type comes from its items, one type per pedido.
    return render json: { ok: false, error: "#{@pedido.rotulo_lixeira} is a #{@pedido.tipo} pedido; #{arquivo.arte.titulo} goes into a #{tipo} one" }, status: :unprocessable_content unless @pedido.aceita_tipo?(tipo)

    session[:current_pedido_uuid] = @pedido.uuid

    ItemPedido.transaction do
      @pedido.update!(tipo: tipo) unless @pedido.tipo == tipo
      item = @pedido.itens_pedido.create!(arquivo: arquivo, materia_prima: materia_prima, metros: (decimal_digitado(params[:metros]) if tipo == "tecido"))
      # A work without corte has no parts (Etapa 2.5c): its sizes are its own files.
      unless @pedido.cliente_do_pedido?
        item.compor_pecas!(MoldeComposicaoService.call(arquivo))
        item.excluir_pecas!(params[:excluir_arquivos])
      end

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

  def atualizar_item
    item = @pedido.itens_pedido.find_by!(uuid: params[:id])
    grade_params = params[:grade]
    if grade_total_after_update(item, grade_params).zero?
      return render json: { ok: false, error: "Quantidade total 0 — use Remover para tirar o item." }, status: :unprocessable_content
    end

    erro = erro_de_grade(item.arte, grade_params)
    return render json: { ok: false, error: erro }, status: :unprocessable_content if erro

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
  # Usage: PATCH /pedidos/:uuid/alternar_peca?id=<item uuid>&peca_uuid=<row uuid>&incluida=false
  def alternar_peca
    error = alternar_peca_error
    return render json: { ok: false, error: error }, status: :unprocessable_content if error

    peca_row = @pedido.itens_pedido.find_by!(uuid: params[:id]).item_pedido_pecas.por_uuid!(params[:peca_uuid])
    peca_row.update!(incluida: params[:incluida] == "true")
    render json: { ok: true, estado: peca_row.estado }
  rescue ActiveRecord::RecordNotFound
    render json: { ok: false, error: "Item #{params[:id].inspect} or piece #{params[:peca_uuid].inspect} not found in pedido #{@pedido.uuid}" }, status: :not_found
  end

  # The "Produção" section alone, reloaded (Turbo Frame) when a piece is
  # checked/unchecked on the pedido page.
  # The factory's Corte page (Etapa 1.2, 3/3 parte 3b): one line per part ×
  # DXF size, its drawing, the pieces to cut and the DXF.
  def corte
    return redirect_to producao_dtf_pedido_path(@pedido, etapa: "corte") if @pedido.dtf?

    @linhas = @pedido.pecas_para_produzir
    @etapa = EtapasProducao.etapa(@pedido.tipo, "corte")
    @situacoes = RegistrarBaixaService.situacao(@pedido, "corte")
  end

  # Every DXF size of the Corte page in one .zip, named by part and size.
  # Usage: GET /pedidos/:uuid/baixar_corte → "Corte a1b2c3d4.zip"
  def baixar_corte
    linhas = @pedido.pecas_para_produzir.select(&:tamanho).uniq(&:tamanho)
    entradas = linhas.to_h { |linha| [ nome_no_zip(linha), DxfDoTamanho.caminho!(linha.tamanho) ] }
    send_data ZipDeArquivos.gerar(entradas), type: "application/zip", disposition: "attachment",
              filename: "Corte #{@pedido.uuid.first(8)}.zip"
  rescue ActionController::MissingFile => e
    redirect_to corte_pedido_path(@pedido), alert: "Não foi possível montar o zip: #{e.message}"
  end

  # The printer's Impressão page (Etapa 1.2, 3/3 parte 3c): per arte, one
  # line per file to print, in pieces.
  def impressao
    return redirect_to producao_dtf_pedido_path(@pedido, etapa: "impressao") if @pedido.dtf?

    @grupos = ImpressaoPedidoService.call(@pedido)
    @etapa = EtapasProducao.etapa(@pedido.tipo, "impressao")
    @situacoes = RegistrarBaixaService.situacao(@pedido, "impressao")
  end

  # Every file of the Impressão page in one .zip, under its full name — built
  # on disk (artes go up to 1 GB), old ones cleaned first.
  # Usage: GET /pedidos/:uuid/baixar_impressao → "Impressao a1b2c3d4.zip"
  def baixar_impressao
    return redirect_to dtf_arquivos_pedido_path(@pedido) if @pedido.dtf?

    arquivos = ImpressaoPedidoService.call(@pedido).flat_map(&:linhas).filter_map(&:arquivo).uniq
    destino = ZipsTemporarios.novo_caminho
    ZipDeArquivos.gravar(entradas_de_impressao(arquivos), destino)
    send_file destino, type: "application/zip", disposition: "attachment", filename: "Impressao #{@pedido.uuid.first(8)}.zip"
  rescue Errno::ENOENT => e
    redirect_to impressao_pedido_path(@pedido), alert: "Não foi possível montar o zip: #{e.message}"
  end

  # The page of a production stage that has none of its own (Etapa 2.2,
  # 2/3): Estamparia and Conferência, on the Impressão's lines. Impressão and
  # Corte keep their pages.
  # Usage: GET /pedidos/:uuid/etapas/estamparia
  def etapa
    @etapa = EtapasProducao.etapa(@pedido.tipo, params[:etapa])
    return redirect_to impressao_pedido_path(@pedido) if @etapa.chave == "impressao"
    return redirect_to corte_pedido_path(@pedido) if @etapa.chave == "corte"

    @grupos = ImpressaoPedidoService.call(@pedido)
    @situacoes = RegistrarBaixaService.situacao(@pedido, @etapa.chave)
  rescue EtapasProducao::Invalida
    head :not_found
  end

  # "Marcar como entregue" (Etapa 2.2, 3/3): JSON for the entrega Stimulus
  # controller — ok, aviso (stages still open: deliver anyway?) or error.
  # Usage: POST /pedidos/:uuid/entregar (confirmar)
  def entregar
    resultado = EntregarPedidoService.call(@pedido, confirmar: params[:confirmar] == "1", user: Current.user)
    case resultado.estado
    when :ok then flash[:notice] = "Pedido entregue."; render json: { ok: true }
    when :aviso then render json: { ok: false, aviso: resultado.mensagem }
    else render json: { ok: false, error: resultado.mensagem }, status: :unprocessable_content
    end
  end

  # "Gerar reposição" (Etapa 2.2, 4/4): the open reposição goes to
  # production before the Conferência ends.
  # Usage: POST /pedidos/:uuid/gerar_reposicao
  def gerar_reposicao
    reposicao = LiberarReposicaoService.call(@pedido)
    voltar = url_from(request.referer) || resumo_pedido_path(@pedido)
    return redirect_to voltar, alert: "There is no open reposição with pieces in this pedido." unless reposicao

    redirect_to voltar, notice: "Reposição ##{reposicao.uuid.first(8)} enviada para a produção (#{reposicao.itens_reposicao.sum(:pecas)} peças)."
  end

  def resumo
    render :show
  end

  # The pedido page's "add an arte" (Etapa 1.2, 3/3): molde → referência →
  # arte, each choice narrowing the next.
  # Usage: GET /pedidos/artes_para_adicionar.json?molde_uuid=…&referencia_uuid=…
  def artes_para_adicionar
    if Pedido::DO_CLIENTE_DO_PEDIDO.include?(params[:tipo])
      # Etapa 2.6b1, 2.7a: the coleção geral included (a GET reads it).
      return render json: { artes: BuscaDeObras.call(visiveis(Arquivo), params[:tipo], params[:q]).map { |arquivo| arte_para_adicionar_json(arquivo) } }
    end

    molde = visiveis(Molde).ativos.por_uuid!(params[:molde_uuid])
    artes = visiveis(Arquivo).ativos.where(category: "artes", molde: molde)
    artes = artes.where(referencia: molde.referencias.por_uuid!(params[:referencia_uuid])) if params[:referencia_uuid].present?
    render json: {
      referencias: molde.referencias.order(:nome).map { |r| { uuid: r.uuid, nome: r.nome } },
      artes: artes.principais_das_artes.includes(:arte, :client, :referencia, molde: :modelo).order(:nome).map { |arquivo| arte_para_adicionar_json(arquivo) }
    }
  end

  private

  # Each file under its full name (NomeDeArte, without accents or path
  # characters), numbered when two would collide.
  def entradas_de_impressao(arquivos)
    arquivos.each_with_object({}) do |arquivo, entradas|
      base = arquivo.nome_completo(para_arquivo: true) || arquivo.filename
      nome = "#{base}.#{arquivo.approved_version.extension}"
      nome = "#{base} (#{entradas.size + 1}).#{arquivo.approved_version.extension}" if entradas.key?(nome)
      entradas[nome] = arquivo.approved_original_path.to_s
    end
  end

  # "Lateral 29-30 - 24 AO 34 CABEDAL.dxf" — part, size and corte, without
  # path characters (the names are typed by users).
  def nome_no_zip(linha)
    nome = "#{linha.peca&.nome || "Sem peça"} #{linha.tamanho.nome} - #{linha.corte.filename}"
    "#{I18n.transliterate(nome).gsub(%r{[/\\:*?"<>|]}, "-")}.dxf"
  end

  # The pedido page adds to itself; the gallery to the client's draft of the
  # item's type, else the one in session when of that type, else a new one
  # (Etapa 2.6b1: a draft never mixes types). A DTF's client is the
  # pedido's (D4): a cliente final's own, else the etiqueta's when it is no
  # catálogo work — the team picks it on the pedido otherwise.
  def pedido_de_destino(arquivo, tipo)
    return visiveis(Pedido).por_uuid!(params[:pedido_uuid]) if params[:pedido_uuid].present?

    rascunhos = visiveis(Pedido).ativos.rascunhos.where(reposicao_de_id: nil)
    client_id = cliente_do_pedido(arquivo, tipo)
    return rascunhos.find_by(client_id: client_id, tipo: tipo) || visiveis(Pedido).create!(status: "rascunho", client_id: client_id, tipo: tipo) if client_id

    da_sessao = rascunhos.find_by(uuid: session[:current_pedido_uuid])
    da_sessao&.aceita_tipo?(tipo) ? da_sessao : visiveis(Pedido).create!(status: "rascunho", tipo: tipo)
  end

  def cliente_do_pedido(arquivo, tipo)
    return arquivo.client_id unless Pedido::DO_CLIENTE_DO_PEDIDO.include?(tipo)
    return Current.user.cliente.id if cliente_final?

    arquivo.client_id unless arquivo.arte.no_catalogo
  end

  # Etapa 2.7a: a tecido item is ordered in meters, the others by grade.
  def erro_da_quantidade(tipo)
    return erro_dos_metros(decimal_digitado(params[:metros])) if tipo == "tecido"

    "Informe ao menos 1 unidade (quantidade total 0)." if grade_param_total(params[:grade]).zero?
  end

  # The item's own rule (one decimal), checked before any draft is created.
  def erro_dos_metros(metros)
    return "Informe os metros (maior que 0)." if metros.to_d <= 0

    ItemPedido.new(metros: metros).tap(&:validate).errors.full_messages_for(:metros).first
  end

  # A DTF is printed on the film, never on a material (Etapa 2.6b1); a
  # tecido on a fabric that prints (Dublagem 1/5) — the one chosen, else the
  # cor lisa's (Etapa 2.7a); a calçado's parts are cut from a fabric, never
  # an insumo (28/10/2026).
  def material_do_item(arquivo, tipo)
    return nil if tipo == "dtf"
    return (tipo == "tecido" ? visiveis(MateriaPrima).estampaveis : visiveis(MateriaPrima).tecidos).por_uuid!(params[:materia_prima_uuid]) if params[:materia_prima_uuid].present?

    arquivo.arte.materia_prima if tipo == "tecido"
  end

  # Etapa 1.2 (3/3): the grade is by the arte's individual sizes — any of
  # its product's grade (Arte#grade_completa_do_pedido) — or a single
  # "_total" when it has none.
  def erro_de_grade(arte, grade_params)
    return nil unless grade_params.respond_to?(:each)

    permitidos = arte&.grade_completa_do_pedido.presence || [ ProducaoPedidoService::TOTAL_KEY ]
    estranhos = grade_params.to_unsafe_h.keys - permitidos
    "Sizes #{estranhos.join(", ")} are not in this arte's grade; expected some of #{permitidos.join(", ")}" if estranhos.any?
  end

  def situacao_do_pedido
    return "an old-grade pedido" if @pedido.grade_antiga?
    return "a pedido in the trash" if @pedido.excluido?

    @pedido.status
  end

  # A catálogo work of another client never says whose it is (Etapa 2.5a).
  def arte_para_adicionar_json(arquivo)
    dono = arquivo.client if helpers.do_proprio_cliente?(arquivo)
    {
      arquivo_uuid: arquivo.uuid, titulo: arquivo.arte.titulo, filename: arquivo.filename, tipo: arquivo.arte.tipo,
      client: dono&.name, client_uuid: dono&.uuid,
      preview: (preview_arquivo_path(arquivo) if arquivo.preview_file.present?),
      resumo: helpers.resumo_da_arte(arquivo), tamanhos: helpers.tamanhos_for_arte(arquivo),
      grade_completa: helpers.grade_completa_for_arte(arquivo)
    }
  end

  # Sum of the positive quantities in a grade param ({"35"=>"2", "_total"=>"1"}).
  def grade_param_total(grade_params)
    return 0 unless grade_params.respond_to?(:each)

    grade_params.to_unsafe_h.values.sum { |qtd| [ qtd.to_i, 0 ].max }
  end

  # Total the item would have after atualizar_item: sizes sent replace the
  # stored ones, sizes not sent keep their quantity.
  def grade_total_after_update(item, grade_params)
    enviados = grade_params.respond_to?(:each) ? grade_params.to_unsafe_h.transform_values(&:to_i) : {}
    mantidos = item.grades.reject { |g| enviados.key?(g.tamanho_nome) }.sum(&:quantidade)
    mantidos + enviados.values.sum { |qtd| [ qtd, 0 ].max }
  end

  def alternar_peca_error
    return "incluida must be \"true\" or \"false\", got #{params[:incluida].inspect}" unless %w[true false].include?(params[:incluida])

    nil
  end

  def set_pedido
    @pedido = visiveis(Pedido).find_by!(uuid: params[:uuid])
  end

  # A trashed pedido stays readable (show, resumo, produção) but frozen until
  # it is restored from /lixeira.
  # Also a pedido from before Etapa 1.2 (3/3), its grade by the corte's size
  # name: read only for good.
  def recusar_pedido_excluido
    return unless @pedido.excluido? || @pedido.grade_antiga?

    message = if @pedido.grade_antiga?
      "#{@pedido.rotulo_lixeira} has the old grade (by the corte's size name); it is read only"
    else
      "#{@pedido.rotulo_lixeira} is in the trash; restore it from Lixeira before changing it"
    end
    respond_to do |format|
      format.json { render json: { ok: false, error: message }, status: :unprocessable_content }
      format.any { redirect_to resumo_pedido_path(@pedido), alert: message }
    end
  end

  # Etapa 2.8 (5/5): items, grade and parts change only while editable — a
  # draft, or one sent to the factory for the team. Before this, a confirmed
  # pedido's grade still took atualizar_item.
  def recusar_pedido_travado
    return if @pedido.editavel?(cliente_final: cliente_final?)

    message = if @pedido.status == "enviado"
      "#{@pedido.rotulo_lixeira} is waiting for the factory; take it back (Retirar o envio) to change it"
    else
      "#{@pedido.rotulo_lixeira} is #{@pedido.status}; items, grade and parts change only while it is rascunho"
    end
    respond_to do |format|
      format.json { render json: { ok: false, error: message }, status: :unprocessable_content }
      format.any { redirect_to resumo_pedido_path(@pedido), alert: message }
    end
  end

  def levar_tecido_a_producao
    return unless @pedido.tecido?

    redirect_to action_name == "baixar_impressao" ? tecido_arquivos_pedido_path(@pedido) : producao_tecido_pedido_path(@pedido, etapa: "impressao")
  end

  def pedido_params
    params.permit(:observacoes)
  end
end
