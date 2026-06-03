require "rails_helper"

RSpec.describe "Pecas", type: :request do
  describe "GET /pecas" do
    it "renders the index page" do
      create(:peca, nome: "Solado")

      get pecas_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Solado")
    end
  end

  describe "POST /pecas" do
    it "creates a peca with valid params" do
      expect {
        post pecas_path, params: { peca: { nome: "Solado" } }
      }.to change(Peca, :count).by(1)

      expect(Peca.last.nome).to eq("Solado")
    end
  end

  describe "GET /pecas/search" do
    it "returns matching pecas as JSON" do
      create(:peca, nome: "Solado")

      get search_pecas_path, params: { q: "Sola" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Solado")
    end
  end

  describe "GET /pecas/for_cascade" do
    it "returns pecas for a given molde and client" do
      molde = create(:molde, nome: "Sapato")
      peca = create(:peca, nome: "Solado")
      molde.pecas << peca
      client = create(:client, name: "Test Client", responsible: "John")
      create(:arquivo, molde: molde, peca: peca, client: client, organized: true)

      get for_cascade_pecas_path(molde_id: molde.id, client_id: client.id)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Solado")
    end

    it "returns pecas from organized arquivos regardless of tipo_corte" do
      molde = create(:molde)
      peca = create(:peca, nome: "Solado")
      molde.pecas << peca
      create(:arquivo, tipo_corte: "apenas_corte", molde: molde, peca: peca, organized: true)

      get for_cascade_pecas_path(molde_id: molde.id)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Solado")
    end

    it "returns empty array when no organized arquivos exist" do
      molde = create(:molde)
      peca = create(:peca)
      molde.pecas << peca

      get for_cascade_pecas_path(molde_id: molde.id)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end
  end

  describe "PATCH /pecas/:id" do
    it "updates a peca" do
      peca = create(:peca, nome: "Solado")

      patch peca_path(peca), params: { peca: { nome: "Peca Atualizada" } }

      peca.reload
      expect(peca.nome).to eq("Peca Atualizada")
    end
  end

  describe "DELETE /pecas/:id" do
    it "destroys a peca" do
      peca = create(:peca, nome: "Solado")

      expect {
        delete peca_path(peca)
      }.to change(Peca, :count).by(-1)
    end
  end
end
