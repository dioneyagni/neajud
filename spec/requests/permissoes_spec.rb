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
    [ "see a size's drawing", "pedidos", 1, -> { get preview_tamanho_path(tamanho) } ],
    [ "set a molde part's pieces per pair", "catalogo", 2, -> { patch update_peca_config_molde_path(molde, molde_peca_uuid: molde.molde_pecas.create!(peca: create(:peca)).uuid), params: { pecas_por_par: "2" } } ],
    [ "create a pedido", "pedidos", 2, -> { post pedidos_path } ],
    [ "list artes to add to a pedido", "pedidos", 2, -> { get artes_para_adicionar_pedidos_path(molde_uuid: molde.uuid), as: :json } ],
    [ "trash a pedido", "pedidos", 3, -> { delete pedido_path(pedido) } ],
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
    [ "trash a corte (Catálogo)", "catalogo", 3, -> { delete arquivo_path(corte) } ],
    [ "list modelos", "catalogo", 1, -> { get modelos_path } ],
    [ "register a peça", "catalogo", 2, -> { post pecas_path, params: { peca: { nome: "Nova" } } } ],
    [ "trash a molde", "catalogo", 3, -> { delete molde_path(molde) } ],
    [ "add a part to a molde", "catalogo", 2, -> { post adicionar_parte_molde_path(molde), params: { peca_uuid: peca.uuid } } ],
    [ "remove a molde's part", "catalogo", 2, -> { delete remover_parte_molde_path(molde, molde_peca_uuid: molde.molde_pecas.create!(peca: create(:peca)).uuid) } ],
    [ "list materials", "estoque", 1, -> { get materiais_path } ],
    [ "open the new movement form", "estoque", 2, -> { get new_movimento_path } ],
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

    it "the Usuários page needs gerenciar_usuarios" do
      entrar_com_funcao(niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: %w[baixar_producao])
      get usuarios_path
      expect(response).to have_http_status(:forbidden)
    end

    it "the Funções page is the dono's only, whatever the grid says" do
      entrar_com_funcao(niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: Autorizacao::ACOES)
      get funcoes_path
      expect(response).to have_http_status(:forbidden)
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
