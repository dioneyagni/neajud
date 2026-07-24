require "rails_helper"

RSpec.describe "Modelos", type: :request do
  describe "GET /modelos" do
    it "renders the index page" do
      client = create(:client, name: "Test Client", responsible: "John")
      create(:modelo, nome: "Air Max", client: client)

      get modelos_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Air Max")
    end
  end

  describe "GET /modelos/:id" do
    it "renders the show page" do
      client = create(:client, name: "Test Client", responsible: "John")
      modelo = create(:modelo, nome: "Air Max", client: client)

      get modelo_path(modelo)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Air Max")
    end

    it "renders modelo_pecas with corte status when molde has pecas" do
      client = create(:client, name: "Test Client", responsible: "John")
      molde = create(:molde)
      peca1 = create(:peca, nome: "Frente")
      peca2 = create(:peca, nome: "Costa")
      MoldePeca.create!(molde: molde, peca: peca1)
      MoldePeca.create!(molde: molde, peca: peca2)

      modelo = create(:modelo, nome: "Camisa", client: client, molde: molde)
      modelo.sync_modelo_pecas!

      corte = create(:arquivo, :corte, filename: "frente.dxf", client: client, modelo: modelo,
                     molde: molde, peca: peca1, organized: true)

      get modelo_path(modelo)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Frente")
      expect(response.body).to include("Costa")
      expect(response.body).to include("frente.dxf")
      expect(response.body).to include("Corte ausente")
    end

    it "auto-syncs modelo_pecas when molde assigned but no records exist" do
      client = create(:client, name: "Test Client", responsible: "John")
      molde = create(:molde)
      peca = create(:peca, nome: "Manga")
      MoldePeca.create!(molde: molde, peca: peca)

      modelo = create(:modelo, nome: "Regata", client: client, molde: molde)
      expect(modelo.modelo_pecas.count).to eq(0)

      get modelo_path(modelo)

      expect(response).to have_http_status(:success)
      expect(modelo.reload.modelo_pecas.count).to eq(1)
    end
  end

  describe "PATCH /modelos/:id/update_peca_config" do
    it "toggles needs_cut for a modelo_peca" do
      client = create(:client, name: "Test Client", responsible: "John")
      molde = create(:molde)
      peca = create(:peca, nome: "Frente")
      MoldePeca.create!(molde: molde, peca: peca)

      modelo = create(:modelo, nome: "Camisa", client: client, molde: molde)
      modelo.sync_modelo_pecas!
      mp = modelo.modelo_pecas.first

      expect(mp.needs_cut).to be true

      patch update_peca_config_modelo_path(modelo), params: { modelo_peca_id: mp.id, needs_cut: "false" }

      expect(response).to redirect_to(modelo_path(modelo))
      expect(mp.reload.needs_cut).to be false
    end
  end

  describe "POST /modelos" do
    it "creates a modelo with valid params" do
      client = create(:client, name: "Test Client", responsible: "John")

      expect {
        post modelos_path, params: { modelo: { nome: "Air Max", client_id: client.id } }
      }.to change(Modelo, :count).by(1)

      expect(Modelo.last.nome).to eq("Air Max")
    end
  end

  describe "GET /modelos/search" do
    it "returns matching modelos as JSON" do
      client = create(:client, name: "Test Client", responsible: "John")
      create(:modelo, nome: "Air Max", client: client)

      get search_modelos_path, params: { q: "Air" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Air Max")
    end
  end

  describe "GET /modelos/for_client" do
    it "returns modelos for a given client" do
      client = create(:client, name: "Test Client", responsible: "John")
      create(:modelo, nome: "Air Max", client: client)

      get for_client_modelos_path(client_id: client.id)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
    end
  end

  describe "PATCH /modelos/:id" do
    it "updates a modelo" do
      client = create(:client, name: "Test Client", responsible: "John")
      modelo = create(:modelo, nome: "Air Max", client: client)

      patch modelo_path(modelo), params: { modelo: { nome: "Air Max 2" } }

      modelo.reload
      expect(modelo.nome).to eq("Air Max 2")
    end
  end

  describe "DELETE /modelos/:id" do
    it "destroys a modelo" do
      client = create(:client, name: "Test Client", responsible: "John")
      modelo = create(:modelo, nome: "Air Max", client: client)

      expect {
        delete modelo_path(modelo)
      }.to change(Modelo, :count).by(-1)
    end
  end
end
