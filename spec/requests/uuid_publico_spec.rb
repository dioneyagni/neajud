require "rails_helper"

# Etapa 1.1 (1/2): the uuid is the only identifier that leaves the server —
# URLs, JSON and form values. The integer id stays the internal key and must
# not work from outside: a guessable sequence would let the future cliente
# final (Etapa 2.8) walk into other clients' records.
RSpec.describe "Public identifiers are uuids", type: :request do
  UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  describe "pages addressed by uuid, not by integer id" do
    {
      "client" => [ :client, ->(r) { "/clients/#{r}" } ],
      "modelo" => [ :modelo, ->(r) { "/modelos/#{r}" } ],
      "peça (edit)" => [ :peca, ->(r) { "/pecas/#{r}/edit" } ],
      "molde" => [ :molde, ->(r) { "/moldes/#{r}" } ],
      "pedido's Corte page" => [ :pedido, ->(r) { "/pedidos/#{r}/corte" } ],
      "pedido's Impressão page" => [ :pedido, ->(r) { "/pedidos/#{r}/impressao" } ],
      "pedido's Estamparia page" => [ :pedido, ->(r) { "/pedidos/#{r}/etapas/estamparia" } ]
    }.each do |nome, (factory, caminho)|
      it "opens a #{nome} by uuid and answers 404 to its integer id" do
        registro = create(factory)
        get caminho.call(registro.uuid)
        expect(response).to have_http_status(:ok)
        get caminho.call(registro.id)
        expect(response).to have_http_status(:not_found)
      end
    end

    it "refuses a tamanho download by integer id" do
      tamanho = create(:tamanho)
      get "/tamanhos/#{tamanho.id}/download"
      expect(response).to have_http_status(:not_found)
    end

    # Etapa 2.4: a molde's price band is edited and removed by its uuid.
    it "refuses a price band by integer id" do
      faixa = create(:molde).faixas_de_preco.create!(tamanho_inicial: "20", tamanho_final: "30", preco_par: 9)
      delete "/moldes/#{faixa.molde.uuid}/faixas/#{faixa.id}"
      expect(response).to have_http_status(:not_found)
      expect(FaixaDePreco.exists?(faixa.id)).to be(true)
    end

    # Etapa 2.6b1: a DTF line's extra rows are addressed by the item's uuid.
    it "refuses a DTF pedido and its item by integer id" do
      pedido = create(:pedido, tipo: "dtf")
      item = create(:item_pedido, :com_quantidade, pedido: pedido)
      patch "/pedidos/#{pedido.id}/dtf", params: { entrega: "cortada" }
      expect(response).to have_http_status(:not_found)
      patch "/pedidos/#{pedido.uuid}/dtf/fileiras", params: { item_uuid: item.id, tamanho_nome: "_total", fileiras_extras: "2" }
      expect([ response.status, item.grades.first.reload.fileiras_extras ]).to eq([ 404, nil ])
      # Etapa 2.6c: a line's price, an etiqueta's and a client's, by uuid only.
      patch "/pedidos/#{pedido.uuid}/dtf/preco_linha", params: { item_uuid: item.id, tamanho_nome: "_total", preco_unidade: "2" }
      expect([ response.status, item.grades.first.reload.preco_unidade ]).to eq([ 404, nil ])
      patch "/clients/#{item.arquivo.client.id}/precos_dtf", params: { preco_metro_dtf: "2" }
      expect(response).to have_http_status(:not_found)
    end

    # Etapa 2.7a: a tecido pedido, its item and its fabric by uuid only.
    it "refuses a tecido pedido, its item and its fabric by integer id" do
      pedido = create(:pedido, tipo: "tecido")
      item = create(:item_pedido, pedido: pedido, metros: 2)
      material = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Oxford"), cor_material: CorMaterial.create!(nome: "Azul"), largura: "1.60", gramatura: "1g")
      patch "/pedidos/#{pedido.id}/tecido", params: { dono_tecido: "empresa" }
      expect(response).to have_http_status(:not_found)
      patch "/pedidos/#{pedido.uuid}/tecido/item", params: { item_uuid: item.id, metros: "5" }
      expect([ response.status, item.reload.metros ]).to eq([ 404, 2 ])
      patch "/pedidos/#{pedido.uuid}/tecido/item", params: { item_uuid: item.uuid, materia_prima_uuid: material.id }
      expect([ response.status, item.reload.materia_prima ]).to eq([ 404, nil ])
      # Etapa 2.7b: an item's prices, its approval and a client's price.
      patch "/pedidos/#{pedido.uuid}/tecido/preco_item", params: { item_uuid: item.id, preco_impressao_metro: "5" }
      expect([ response.status, item.reload.preco_impressao_metro ]).to eq([ 404, nil ])
      Empresa.atual.update!(metragem_minima_tecido: 10)
      post "/pedidos/#{pedido.id}/tecido/aprovar_minimo", params: { item_uuid: item.uuid }
      expect([ response.status, item.reload.minimo_aprovado_em ]).to eq([ 404, nil ])
      patch "/clients/#{create(:client).id}/precos_tecido", params: { preco_impressao_metro_tecido: "5" }
      expect(response).to have_http_status(:not_found)
      # 20/10/2026: repeating it.
      get "/pedidos/#{pedido.id}/repetir"
      expect(response).to have_http_status(:not_found)
      expect { post "/pedidos/#{pedido.id}/repetir" }.not_to change(Pedido, :count)
      # Etapa 2.7c: its production page and files for the RIP.
      %w[tecido/producao/impressao tecido/arquivos tecido/compactados].each do |caminho|
        get "/pedidos/#{pedido.id}/#{caminho}"
        expect(response).to have_http_status(:not_found)
      end
      pedido.update_columns(status: "confirmado") # a draft's files never go to the RIP
      get "/pedidos/#{pedido.uuid}/tecido/arquivo", params: { linha: "#{item.id}/#{item.arquivo.id}" }
      expect(response).to have_http_status(:not_found)
    end

    # Etapa 2.3d1: a draft's fabric owner and paper, by uuid only.
    it "refuses a pedido and its paper by integer id" do
      pedido = create(:pedido)
      papel = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Papel"), cor_material: CorMaterial.create!(nome: "Branco"), largura: "1.60", gramatura: "1g", tipo: "papel")
      patch "/pedidos/#{pedido.id}/materiais", params: { dono_tecido: "empresa" }
      expect([ response.status, pedido.reload.dono_tecido ]).to eq([ 404, nil ])
      patch "/pedidos/#{pedido.uuid}/materiais", params: { material_impressao_uuid: papel.id }
      expect([ response.status, pedido.reload.material_impressao ]).to eq([ 404, nil ])
    end

    it "refuses a tamanho drawing by integer id" do
      tamanho = create(:tamanho)
      get "/tamanhos/#{tamanho.id}/preview"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "JSON endpoints answer uuids in id" do
    let(:client) { create(:client, name: "Cliente Uuid") }
    let(:modelo) { create(:modelo, nome: "Modelo Uuid") }
    let(:peca) { create(:peca, nome: "Peça Uuid") }
    let(:molde) { create(:molde, sufixo: "Molde Uuid", client: client, modelo: modelo) }

    before do
      corte = create(:arquivo, :corte, organized: true, modelo: modelo, peca: peca, client: client)
      corte.moldes << molde
      create(:tamanho, arquivo: corte, nome: "33-34")
      grupo = GrupoMaterial.create!(nome: "Grupo Uuid")
      cor = CorMaterial.create!(nome: "Azul")
      mp = MateriaPrima.create!(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")
      MovimentoEstoque.create!(client: client, materia_prima: mp, tipo: "entrada", quantidade: 1)
    end

    def ids_de(caminho)
      get caminho
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body).map { |linha| linha["id"] }
    end

    it "for every search and cascade endpoint" do
      caminhos = [
        "/clients/search?q=Uuid", "/modelos/search?q=Uuid", "/pecas/search?q=Uuid", "/moldes/search?q=Uuid",
        "/moldes/for_client?client_uuid=#{client.uuid}",
        "/pecas/for_cascade?molde_uuid=#{molde.uuid}",
        "/tamanhos/for_cascade?molde_uuid=#{molde.uuid}&peca_uuid=#{peca.uuid}",
        "/materiais/grupos?q=Uuid", "/materiais/cores", "/materiais/search?client_uuid=#{client.uuid}"
      ]
      caminhos.each do |caminho|
        ids = ids_de(caminho)
        expect(ids).not_to be_empty, "#{caminho} returned nothing"
        expect(ids).to all(match(UUID)), "#{caminho} answered #{ids.inspect}"
      end
    end

    it "points a molde at its modelo by uuid" do
      get "/moldes/for_client?client_uuid=#{client.uuid}"
      expect(JSON.parse(response.body).first["modelo_uuid"]).to eq(modelo.uuid)
    end
  end

  # Etapa 2.8 (3b): Turbo named a page's stream "gid://neajud-app/Arquivo/232",
  # base64 in the page — the integer id left the server. Cards had it as dom_id.
  describe "live streams and cards" do
    it "names every stream by uuid, through AoVivoChannel" do
      arte = create(:arquivo)
      pedido = create(:pedido)
      { arquivos_path => CanaisAoVivo::EQUIPE, arquivo_path(arte) => "arquivo:#{arte.uuid}", pedido_path(pedido) => "pedido:#{pedido.uuid}" }.each do |url, nome|
        get url
        fontes = Nokogiri::HTML(response.body).css("turbo-cable-stream-source")
        expect(fontes.map { |f| [ f["channel"], CanaisAoVivo.ler(f["signed-stream-name"]) ] }).to eq([ [ "AoVivoChannel", nome ] ]), url
      end
    end

    it "gives the gallery card its uuid as DOM id" do
      arte = create(:arquivo)
      get arquivos_path
      expect(Nokogiri::HTML(response.body).at_css(".stamp-card")["id"]).to eq("arquivo_#{arte.uuid}")
    end
  end

  describe "forms send uuids" do
    it "lists the molde dialog's clients and modelos by uuid" do
      client = create(:client)
      modelo = create(:modelo)
      get moldes_path
      expect(response.body).to include(%(<option value="#{client.uuid}">), %(<option value="#{modelo.uuid}" data-grade=))
    end
  end
end
