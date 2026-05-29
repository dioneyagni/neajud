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
