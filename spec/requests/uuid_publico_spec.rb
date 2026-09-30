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
      "molde" => [ :molde, ->(r) { "/moldes/#{r}" } ],
      "peça (edit)" => [ :peca, ->(r) { "/pecas/#{r}/edit" } ],
      "modelo" => [ :modelo, ->(r) { "/modelos/#{r}" } ]
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

    it "opens a pedido's pending piece by its uuid" do
      item = create(:item_pedido, pedido: create(:pedido), arquivo: create(:arquivo, modelo: create(:modelo)))
      linha = create(:item_pedido_peca, item_pedido: item, arquivo: nil)
      get "/pedidos/#{item.pedido.uuid}/pecas/#{linha.uuid}/escolher_arte"
      expect(response).to have_http_status(:ok)
      get "/pedidos/#{item.pedido.uuid}/pecas/#{linha.id}/escolher_arte"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "JSON endpoints answer uuids in id" do
    let(:client) { create(:client, name: "Cliente Uuid") }
    let(:molde) { create(:molde, nome: "Molde Uuid") }
    let(:peca) { create(:peca, nome: "Peça Uuid") }

    before do
      molde.pecas << peca
      create(:modelo, nome: "Modelo Uuid", client: client, molde: molde)
      corte = create(:arquivo, :corte, organized: true, molde: molde, peca: peca, client: client)
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
        "/clients/search?q=Uuid", "/moldes/search?q=Uuid", "/pecas/search?q=Uuid", "/modelos/search?q=Uuid",
        "/moldes/#{molde.uuid}/pecas", "/modelos/for_client?client_uuid=#{client.uuid}",
        "/pecas/for_cascade?molde_uuid=#{molde.uuid}&client_uuid=#{client.uuid}",
        "/tamanhos/for_cascade?molde_uuid=#{molde.uuid}&peca_uuid=#{peca.uuid}",
        "/materiais/grupos?q=Uuid", "/materiais/cores", "/materiais/search?client_uuid=#{client.uuid}"
      ]
      caminhos.each do |caminho|
        ids = ids_de(caminho)
        expect(ids).not_to be_empty, "#{caminho} returned nothing"
        expect(ids).to all(match(UUID)), "#{caminho} answered #{ids.inspect}"
      end
    end

    it "points a modelo at its molde by uuid" do
      get "/modelos/for_client?client_uuid=#{client.uuid}"
      expect(JSON.parse(response.body).first["molde_uuid"]).to eq(molde.uuid)
    end
  end

  describe "forms send uuids" do
    it "lists the modelo dialog's clients and moldes by uuid" do
      client = create(:client)
      molde = create(:molde)
      get modelos_path
      expect(response.body).to include(%(<option value="#{client.uuid}">), %(<option value="#{molde.uuid}">))
    end
  end
end
