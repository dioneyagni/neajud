require "rails_helper"

RSpec.describe "Moldes", type: :request do
  describe "GET /moldes" do
    it "renders the index page" do
      create(:molde, nome: "Sapato")

      get moldes_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sapato")
    end
  end

  describe "GET /moldes/:id" do
    it "renders the show page" do
      molde = create(:molde, nome: "Sapato")

      get molde_path(molde)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sapato")
    end
  end

  describe "POST /moldes" do
    it "creates a molde with valid params" do
      expect {
        post moldes_path, params: { molde: { nome: "Sapato" } }
      }.to change(Molde, :count).by(1)

      expect(Molde.last.nome).to eq("Sapato")
    end
  end

  describe "GET /moldes/search" do
    it "returns matching moldes as JSON" do
      create(:molde, nome: "Sapato")

      get search_moldes_path, params: { q: "Sap" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Sapato")
    end
  end

  describe "GET /moldes/:id/pecas" do
    it "returns pecas for a molde" do
      molde = create(:molde, nome: "Sapato")
      peca = create(:peca, nome: "Solado")
      molde.pecas << peca

      get pecas_molde_path(molde)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Solado")
    end
  end

  describe "PATCH /moldes/:id" do
    it "updates a molde" do
      molde = create(:molde, nome: "Sapato")

      patch molde_path(molde), params: { molde: { nome: "Chinelo" } }

      molde.reload
      expect(molde.nome).to eq("Chinelo")
    end
  end

  describe "DELETE /moldes/:id" do
    it "destroys a molde" do
      molde = create(:molde, nome: "Sapato")

      expect {
        delete molde_path(molde)
      }.to change(Molde, :count).by(-1)
    end
  end
end
