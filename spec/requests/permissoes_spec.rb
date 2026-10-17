require "rails_helper"

# Etapa 0.5 (2/4): every route refuses (403) a função below its requirement
# and lets through one that has exactly it. One row per requirement, not per
# route: the controllers declare them (ControleDeAcesso).
RSpec.describe "Permissões por função", type: :request, sem_login: true do
  let(:arte) { create(:arquivo, category: "artes") }
  let(:corte) { create(:arquivo, :corte) }
  let(:client) { create(:client) }
  let(:modelo) { create(:modelo) }
  let(:peca) { create(:peca) }
  let(:molde) { create(:molde) }
  let(:pedido) { create(:pedido) }
  let(:tamanho) { create(:tamanho, arquivo: corte) }

  # [description, area, level needed, request]
  REQUISITOS = [
    [ "list pedidos", "pedidos", 1, -> { get pedidos_path } ],
    [ "open a pedido", "pedidos", 1, -> { get resumo_pedido_path(pedido) } ],
    [ "open a pedido's Corte page", "pedidos", 1, -> { get corte_pedido_path(pedido) } ],
    [ "open a pedido's Impressão page", "pedidos", 1, -> { get impressao_pedido_path(pedido) } ],
    [ "open a pedido's Estamparia page", "pedidos", 1, -> { get etapa_pedido_path(pedido, etapa: "estamparia") } ],
    [ "set a file's side", "artes", 2, -> { patch definir_lado_arquivo_arte_path(arte), params: { lado: "direito" } } ],
    [ "see a size's drawing", "pedidos", 1, -> { get preview_tamanho_path(tamanho) } ],
    [ "set a molde part's pieces per pair", "catalogo", 2, -> { patch update_peca_config_molde_path(molde, molde_peca_uuid: molde.molde_pecas.create!(peca: create(:peca)).uuid), params: { pecas_por_par: "2" } } ],
    [ "create a pedido", "pedidos", 2, -> { post pedidos_path } ],
    [ "list artes to add to a pedido", "pedidos", 2, -> { get artes_para_adicionar_pedidos_path(molde_uuid: molde.uuid), as: :json } ],
    [ "trash a pedido", "pedidos", 3, -> { delete pedido_path(pedido) } ],
    # Etapa 2.6b1: a DTF draft's delivery, extra rows and client.
    [ "set a DTF pedido's delivery", "pedidos", 2, -> { patch dtf_pedido_path(create(:pedido, tipo: "dtf")), params: { entrega: "cortada" } } ],
    [ "set a DTF line's extra rows", "pedidos", 2, -> { patch dtf_fileiras_pedido_path(create(:pedido, tipo: "dtf")), params: { fileiras_extras: "1" } } ],
    # Etapa 2.7a: a tecido draft's fabric owner and its items.
    [ "set whose fabric a tecido pedido is on", "pedidos", 2, -> { patch tecido_pedido_path(create(:pedido, tipo: "tecido")), params: { dono_tecido: "empresa" } } ],
    [ "set a tecido item's meters", "pedidos", 2, -> { patch tecido_item_pedido_path(create(:pedido, tipo: "tecido")), params: { metros: "1" } } ],
    [ "list clients", "clientes", 1, -> { get clients_path } ],
    [ "register a client", "clientes", 2, -> { post clients_path, params: { client: { name: "Novo", responsible: "X" } } } ],
    [ "trash a client", "clientes", 3, -> { delete client_path(client) } ],
    [ "open an arte", "artes", 1, -> { get arquivo_path(arte) } ],
    [ "edit an arte's time", "artes", 2, -> { patch update_time_arquivo_path(arte), params: { annotated_seconds: 60 } } ],
    [ "set an arte's referência and name", "artes", 2, -> { patch arquivo_nome_arte_path(arte), params: { nome: "X" } } ],
    [ "join a repeated arte as a new version", "artes", 2, -> { post tornar_versao_arquivo_nome_arte_path(arte), params: { original_uuid: arte.uuid } } ],
    [ "take a file out of its arte", "artes", 2, -> { post separar_arquivo_arte_path(arte) } ],
    [ "bring other artes into an arte", "artes", 2, -> { post trazer_arquivo_arte_path(arte), params: { origem_uuids: [ arte.uuid ] } } ],
    [ "add a file to an arte", "artes", 2, -> { post acrescentar_arquivo_arte_path(arte) } ],
    [ "make a file its part's piloto", "artes", 2, -> { post tornar_piloto_arquivo_arte_path(arte) } ],
    [ "create the empty arte of an upload group", "artes", 2, -> { post artes_path, as: :json } ],
    [ "send a piloto back to production", "artes", 2, -> { post voltar_para_producao_arquivo_arte_path(arte) } ],
    [ "trash an arte", "artes", 3, -> { delete arquivo_path(arte) } ],
    [ "open a corte (Catálogo)", "catalogo", 1, -> { get arquivo_path(corte) } ],
    [ "change a corte's cut type (Catálogo)", "catalogo", 2, -> { patch update_tipo_corte_arquivo_path(corte), params: { tipo_corte: "apenas_corte" } } ],
    [ "change how a corte's pieces may turn (Catálogo)", "catalogo", 2, -> { patch update_giro_arquivo_path(corte), params: { giro: "90" } } ],
    [ "trash a corte (Catálogo)", "catalogo", 3, -> { delete arquivo_path(corte) } ],
    [ "list modelos", "catalogo", 1, -> { get modelos_path } ],
    [ "register a peça", "catalogo", 2, -> { post pecas_path, params: { peca: { nome: "Nova" } } } ],
    [ "trash a molde", "catalogo", 3, -> { delete molde_path(molde) } ],
    [ "add a part to a molde", "catalogo", 2, -> { post adicionar_parte_molde_path(molde), params: { peca_uuid: peca.uuid } } ],
    [ "remove a molde's part", "catalogo", 2, -> { delete remover_parte_molde_path(molde, molde_peca_uuid: molde.molde_pecas.create!(peca: create(:peca)).uuid) } ],
    [ "list materials", "estoque", 1, -> { get materiais_path } ],
    [ "open the new movement form", "estoque", 2, -> { get new_movimento_path } ],
    [ "set a material's type and price", "estoque", 2, -> { patch material_path(MateriaPrima.create!(grupo_material: GrupoMaterial.find_or_create_by!(nome: "Oxford"), cor_material: CorMaterial.find_or_create_by!(nome: "Azul"), largura: "1.40", gramatura: "1g")), params: { materia_prima: { preco_metro: "1" } } } ],
    [ "see the trash", "lixeira", 1, -> { get lixeira_path } ],
    [ "restore from the trash", "lixeira", 2, -> { post restaurar_lixeira_path(tipo: "pecas", id: peca.tap { |p| p.excluir!(changed_by: "x") }.uuid) } ]
  ].freeze

  REQUISITOS.each do |descricao, area, nivel, requisicao|
    it "#{descricao}: needs #{area} ≥ #{nivel}" do
      entrar_com_funcao(niveis: { area => nivel - 1 })
      instance_exec(&requisicao)
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Sem permissão", area) if response.media_type == "text/html"
    end

    it "#{descricao}: allowed with #{area} = #{nivel}" do
      entrar_com_funcao(niveis: { area => nivel })
      instance_exec(&requisicao)
      expect(response).not_to have_http_status(:forbidden)
    end
  end

  describe "special actions" do
    it "downloading a size's DXF needs baixar_producao" do
      entrar_com_funcao(niveis: { "catalogo" => 3 })
      get download_tamanho_path(tamanho)
      expect(response).to have_http_status(:forbidden)
    end

    it "the Corte page's zip of DXFs needs baixar_producao" do
      entrar_com_funcao(niveis: { "pedidos" => 3 })
      get baixar_corte_pedido_path(pedido)
      expect(response).to have_http_status(:forbidden)
    end

    it "the Impressão page's zip of artes needs baixar_producao" do
      entrar_com_funcao(niveis: { "pedidos" => 3, "artes" => 3 })
      get baixar_impressao_pedido_path(pedido)
      expect(response).to have_http_status(:forbidden)
    end

    it "a production baixa needs atualizar_producao" do
      entrar_com_funcao(niveis: { "pedidos" => 3 }, acoes: %w[baixar_producao])
      post pedido_baixas_path(pedido), params: { etapa: "corte", nivel: "pedido", medida: "1" }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "delivering a pedido and undoing a baixa need atualizar_producao" do
      p = pedido.tap { |x| x.update!(status: "confirmado") }
      feita = p.baixas_producao.create!(etapa: "corte", nivel: "linha", medida: 1, linhas: %w[a])
      entrar_com_funcao(niveis: { "pedidos" => 3 }, acoes: %w[baixar_producao])
      post entregar_pedido_path(p), as: :json
      expect(response).to have_http_status(:forbidden)
      delete pedido_baixa_path(p, feita)
      expect(response).to have_http_status(:forbidden)
      post gerar_reposicao_pedido_path(p)
      expect(response).to have_http_status(:forbidden)
    end

    it "the Usuários page needs gerenciar_usuarios" do
      entrar_com_funcao(niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: %w[baixar_producao])
      get usuarios_path
      expect(response).to have_http_status(:forbidden)
    end

    # Etapa 2.8 (2/5): a client's access is a password too — gerenciar_usuarios.
    it "a client's Acesso ao sistema needs gerenciar_usuarios" do
      client = create(:client)
      funcao = create(:funcao, :para_cliente)
      entrar_com_funcao(niveis: { "clientes" => 3 })
      get client_path(client)
      expect(response.body).not_to include("Acesso ao sistema")
      post usuarios_path, params: { usuario: { nome: "Bia", email_address: "bia@x.com", funcao_uuid: funcao.uuid, senha_provisoria: "provisoria-123", client_uuid: client.uuid } }
      expect(response).to have_http_status(:forbidden)
      entrar_com_funcao(niveis: { "clientes" => 1 }, acoes: %w[gerenciar_usuarios])
      get client_path(client)
      expect(response.body).to include("Acesso ao sistema")
    end

    # Etapa 2.8 (4a): aprovar_arte is the team's sending and registering, and a
    # cliente final's own answer — never the other side's.
    it "answering an approval in the system needs aprovar_arte and a cliente final" do
      cliente = arte.tap { |a| a.update!(client: client) }.client
      entrar_com_funcao(niveis: { "artes" => 3 }, acoes: %w[aprovar_arte])
      post arquivo_aprovar_no_sistema_path(arte)
      expect(response).to have_http_status(:forbidden)
      entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: create(:funcao, :para_cliente, niveis: { "artes" => 1 })).user)
      post arquivo_pedir_alteracao_path(arte), params: { recado: "x" }
      expect(response).to have_http_status(:forbidden)
    end

    it "sending for approval and registering one are the team's, even with aprovar_arte" do
      arte.update!(client: client)
      entrar_como(create(:vinculo, user: create(:user), client: client, funcao: create(:funcao, :para_cliente, niveis: { "artes" => 1 }, acoes: %w[aprovar_arte])).user)
      post arquivo_solicitacoes_path(arte)
      expect(response).to have_http_status(:forbidden)
      get new_arquivo_aprovacao_path(arte)
      expect(response).to have_http_status(:forbidden)
    end

    # Etapa 2.8 (4b): a cliente final uploads artes into his own artes; the
    # versions, the client and the cortes stay the team's even at his grid's most.
    it "versions, the client and the cortes are the team's, even for a client at his grid's most" do
      arte.update!(client: client, approved_version: create(:arquivo_version, arquivo: arte, version_number: 1))
      corte.moldes << create(:molde, client: client)
      client.update!(visibilidade: { "cortes" => true }) # he sees the corte: refused for being the team's, not a 404
      funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
      entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)
      [
        -> { patch update_client_arquivo_path(arte), params: { client_uuid: "" } },
        -> { post upload_version_arquivo_path(arte) },
        -> { patch approve_version_arquivo_path(arte, version_uuid: arte.approved_version.uuid) },
        -> { post tornar_versao_arquivo_nome_arte_path(arte), params: { original_uuid: arte.uuid } },
        -> { patch update_giro_arquivo_path(corte), params: { giro: "180" } }
      ].each do |pedido|
        instance_exec(&pedido)
        expect(response).to have_http_status(:forbidden), "#{request.method} #{request.path} answered #{response.status}"
      end
      expect(arte.reload.client).to eq(client)
      create(:arquivo_version, arquivo: arte, version_number: 2)
      get arquivo_path(arte)
      expect(response.body).to include("Add a file")
      expect(response.body).not_to include("Upload New Version", "Usar esta versão", "Unlink client")
    end

    it "a cliente final's upload is his client's arte, never a corte" do
      funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
      entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)
      post arquivos_path, params: { arquivo: { original_file: Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/29-30.dxf"), "image/vnd.dxf") } },
                         headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("send cortes (DXF) to the factory")
    end

    # Etapa 2.8 (5/5): the client sends and takes back his draft; confirming
    # and returning it are the factory's, even at his grid's most.
    it "a cliente final sends his draft but never confirms or returns it; the team never sends" do
      rascunho = create(:pedido, client: client)
      rascunho.itens_pedido.create!(arquivo: arte)
      funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
      entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)
      post confirmar_pedido_path(rascunho)
      expect(response).to have_http_status(:forbidden)
      post devolver_pedido_path(rascunho), params: { recado: "x" }
      expect(response).to have_http_status(:forbidden)
      get resumo_pedido_path(rascunho)
      expect(response.body).to include("Enviar para a fábrica")
      expect(response.body).not_to include("Confirmar pedido")
      entrar_com_funcao(niveis: { "pedidos" => 3 })
      post enviar_pedido_path(rascunho)
      expect(response).to have_http_status(:forbidden)
      post retirar_envio_pedido_path(rascunho)
      expect(response).to have_http_status(:forbidden)
      entrar_com_funcao(niveis: { "pedidos" => 1 })
      post devolver_pedido_path(rascunho), params: { recado: "x" }
      expect(response).to have_http_status(:forbidden)
      expect(rascunho.reload.status).to eq("rascunho")
    end

    # Etapa 2.4: prices and costs are management's, not the factory floor's.
    it "pricing a molde needs ver_valores and catalogo: editar" do
      preco = -> { post molde_faixas_path(molde), params: { faixa: { tamanho_inicial: "20", tamanho_final: "30", preco_par: "9" } } }
      entrar_com_funcao(niveis: { "catalogo" => 3 })
      instance_exec(&preco)
      expect(response).to have_http_status(:forbidden)
      entrar_com_funcao(niveis: { "catalogo" => 1 }, acoes: %w[ver_valores])
      instance_exec(&preco)
      expect(response).to have_http_status(:forbidden)
      entrar_com_funcao(niveis: { "catalogo" => 2 }, acoes: %w[ver_valores])
      instance_exec(&preco)
      expect(molde.faixas_de_preco.sole.preco_par).to eq(9)
    end

    # Etapa 2.6c: the DTF's prices too — the client's, the etiqueta's, the pedido's.
    {
      "a client's DTF prices" => [ "clientes", -> { patch precos_dtf_client_path(create(:client)), params: { preco_metro_dtf: "9" } }, -> { Client.where(preco_metro_dtf: 9).exists? } ],
      "an etiqueta's agreed price" => [ "artes", -> { patch arquivo_preco_dtf_path(create(:arquivo, arte: Arte.novo_do_tipo("dtf"))), params: { preco_unidade_combinado: "9" } }, -> { Arquivo.where(preco_unidade_combinado: 9).exists? } ],
      "a DTF pedido's prices" => [ "pedidos", -> { patch dtf_precos_pedido_path(create(:pedido, tipo: "dtf")), params: { preco_metro: "9" } }, -> { Pedido.where(preco_metro: 9).exists? } ],
      # Etapa 2.7b: the tecido's — the client's print price, an item's prices.
      "a client's tecido price" => [ "clientes", -> { patch precos_tecido_client_path(create(:client)), params: { preco_impressao_metro_tecido: "9" } }, -> { Client.where(preco_impressao_metro_tecido: 9).exists? } ],
      "a tecido item's prices" => [ "pedidos", lambda {
        pedido = create(:pedido, tipo: "tecido")
        patch tecido_preco_item_pedido_path(pedido), params: { item_uuid: create(:item_pedido, pedido: pedido, metros: 1).uuid, preco_impressao_metro: "9" }
      }, -> { ItemPedido.where(preco_impressao_metro: 9).exists? } ]
    }.each do |descricao, (area, requisicao, gravou)|
      it "#{descricao} need ver_valores and #{area}: editar" do
        entrar_com_funcao(niveis: { area => 3 })
        instance_exec(&requisicao)
        expect(response).to have_http_status(:forbidden)
        entrar_com_funcao(niveis: { area => 1 }, acoes: %w[ver_valores])
        instance_exec(&requisicao)
        expect(response).to have_http_status(:forbidden)
        entrar_com_funcao(niveis: { area => 2 }, acoes: %w[ver_valores])
        instance_exec(&requisicao)
        expect(instance_exec(&gravou)).to be(true)
      end
    end

    # Etapa 2.7b: an item below the tecido's minimum waits for this action.
    it "approving a tecido item below the minimum needs aprovar_abaixo_do_minimo and pedidos: editar" do
      (Empresa.atual || create(:empresa)).update!(metragem_minima_tecido: 10)
      pedido = create(:pedido, tipo: "tecido")
      item = create(:item_pedido, pedido: pedido, metros: 4)
      entrar_com_funcao(niveis: { "pedidos" => 3 }, acoes: %w[ver_valores])
      post tecido_aprovar_minimo_pedido_path(pedido), params: { item_uuid: item.uuid }
      expect(response).to have_http_status(:forbidden)
      entrar_com_funcao(niveis: { "pedidos" => 1 }, acoes: %w[aprovar_abaixo_do_minimo])
      post tecido_aprovar_minimo_pedido_path(pedido), params: { item_uuid: item.uuid }
      expect(response).to have_http_status(:forbidden)
      entrar_com_funcao(niveis: { "pedidos" => 2 }, acoes: %w[aprovar_abaixo_do_minimo])
      post tecido_aprovar_minimo_pedido_path(pedido), params: { item_uuid: item.uuid }
      expect(item.reload.minimo_aprovado?).to be(true)
    end

    it "the molde's prices, the pedido's values and the arte's cost per pair show only with ver_valores" do
      p = pedido
      create(:item_pedido, :com_preco, pedido: p)
      m = p.itens_pedido.sole.arquivo.molde
      entrar_com_funcao(niveis: { "pedidos" => 3, "catalogo" => 3, "artes" => 3 })
      [ molde_path(m), resumo_pedido_path(p), arquivo_path(p.itens_pedido.sole.arquivo) ].each do |caminho|
        get caminho
        expect(response.body).not_to include("molde-precos", "pedido-valores", "arte-custo-por-par")
      end
      entrar_com_funcao(niveis: { "pedidos" => 1, "catalogo" => 1, "artes" => 1 }, acoes: %w[ver_valores])
      expect([ molde_path(m), resumo_pedido_path(p), arquivo_path(p.itens_pedido.sole.arquivo) ].map { |caminho| get(caminho) && response.body })
        .to match([ include('id="molde-precos"'), include('id="pedido-valores"'), include('id="arte-custo-por-par"') ])
    end

    it "the production parameters are the dono's only, whatever the grid says" do
      entrar_com_funcao(niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: Autorizacao::ACOES)
      get edit_parametros_path
      expect(response).to have_http_status(:forbidden)
    end

    it "the Funções page is the dono's only, whatever the grid says" do
      entrar_com_funcao(niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: Autorizacao::ACOES)
      get funcoes_path
      expect(response).to have_http_status(:forbidden)
    end

    # Etapa 2.8 (3a): the default visibility grants, like Funções — the dono's.
    it "the default Visibilidade is the dono's only, whatever the grid says" do
      entrar_com_funcao(niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: Autorizacao::ACOES)
      get edit_visibilidade_path
      expect(response).to have_http_status(:forbidden)
      patch visibilidade_path, params: { tipos: { cortes: "1" } }
      expect(response).to have_http_status(:forbidden)
    end

    # Etapa 2.8 (3a): a client's exceptions go with its accesses — gerenciar_usuarios.
    it "a client's visibility exceptions need gerenciar_usuarios" do
      excecao = -> { patch visibilidade_client_path(client), params: { tipos: { cortes: "1" } } }
      entrar_com_funcao(niveis: { "clientes" => 3 })
      instance_exec(&excecao)
      expect(response).to have_http_status(:forbidden)
      get client_path(client)
      expect(response.body).not_to include("Visibilidade para o cliente")
      entrar_com_funcao(niveis: { "clientes" => 1 }, acoes: %w[gerenciar_usuarios])
      instance_exec(&excecao)
      expect(client.reload.visibilidade).to eq({ "cortes" => true })
    end
  end

  describe "JSON endpoints" do
    it "answer 403 with the requirement in JSON" do
      entrar_com_funcao
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte.uuid }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq("ok" => false, "error" => "No permission: needs pedidos: editar")
    end
  end

  describe "the gallery" do
    it "lists only the categories the função can see" do
      create(:arquivo, category: "artes", filename: "so-arte")
      create(:arquivo, :corte, filename: "so-corte")
      entrar_com_funcao(niveis: { "catalogo" => 1 })
      get arquivos_path
      expect(response.body).to include("so-corte")
      expect(response.body).not_to include("so-arte")
    end

    it "batch-deletes only what the função may delete, reporting the rest" do
      a, c = arte, corte
      entrar_com_funcao(niveis: { "artes" => 3, "catalogo" => 1 })
      delete batch_destroy_arquivos_path, params: { ids: [ a.uuid, c.uuid ] }, as: :json
      expect(response.parsed_body).to eq("destroyed" => 1, "errors" => [ { "uuid" => c.uuid, "error" => "no permission to delete it" } ])
      expect([ a.reload.excluido?, c.reload.excluido? ]).to eq([ true, false ])
    end
  end

  describe "what the screens show" do
    it "the menu lists only visible áreas; Funções only for the dono" do
      entrar_com_funcao(niveis: { "pedidos" => 1, "artes" => 1 })
      get pedidos_path
      nav = response.body[/<nav class="header-nav">.*?<\/nav>/m]
      expect(nav).to include("Pedidos")
      expect(nav).not_to include("Clients", "Modelos", "Materials", "Lixeira", "Funções")
    end

    it "read-only users see no create/edit/delete buttons" do
      create(:peca, nome: "Lateral")
      entrar_com_funcao(niveis: { "catalogo" => 1 })
      get pecas_path
      expect(response.body).to include("Lateral")
      expect(response.body).not_to include("New Peça", ">Edit<", "Delete")
    end

    it "an arte page shows its edit controls only to who may edit it" do
      entrar_com_funcao(niveis: { "artes" => 1 })
      get arquivo_path(arte)
      expect(response.body).not_to include("btn-edit", "Upload New Version", "Delete Arquivo", "Download Original")
    end

    it "flags on <body> hide the broadcast-rendered card controls" do
      entrar_com_funcao(niveis: { "artes" => 1 })
      get arquivos_path
      expect(response.body).to include('data-pode-adicionar-ao-pedido="false"', 'data-pode-excluir-arquivos="false"')
    end

    it "a pedido is read-only without pedidos: editar" do
      p = pedido
      entrar_com_funcao(niveis: { "pedidos" => 1 })
      get resumo_pedido_path(p)
      expect(response.body).not_to include("Confirmar pedido", "Excluir rascunho")
    end

    it "the trash hides Restore from who can only see it" do
      peca.excluir!(changed_by: "x")
      entrar_com_funcao(niveis: { "lixeira" => 1 })
      get lixeira_path
      expect(response.body).to include(peca.nome)
      expect(response.body).not_to include("Restore")
    end
  end
end
