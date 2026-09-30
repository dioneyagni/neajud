require "rails_helper"

RSpec.describe "Pecas", type: :request do
  describe "GET /pecas" do
    it "renders the index page, with the moldes that use each piece" do
      create(:molde, nome: "001-TNS").molde_pecas.create!(peca: create(:peca, nome: "Solado"))

      get pecas_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Solado", "001-TNS")
    end
  end

  describe "GET /pecas/new" do
    it "renders the new page" do
      get new_peca_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Register New Peça")
    end
  end

  describe "POST /pecas" do
    it "creates a peca with valid params" do
      expect {
        post pecas_path, params: { peca: { nome: "Solado" } }
      }.to change(Peca, :count).by(1)

      expect(Peca.last.nome).to eq("Solado")
    end

    it "redirects to pecas index on success" do
      post pecas_path, params: { peca: { nome: "Solado" } }

      expect(response).to redirect_to(pecas_path)
    end

    it "renders new on validation failure" do
      post pecas_path, params: { peca: { nome: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Register New Peça")
    end

    # "Register new piece" from a molde's page (Etapa 1.1, 3/5).
    it "adds the new piece as a part of the molde it came from" do
      molde = create(:molde, nome: "001-TNS")

      post pecas_path, params: { peca: { nome: "Solado" }, molde_uuid: molde.uuid }

      expect(response).to redirect_to(molde_path(molde))
      expect(molde.molde_pecas.map { |mp| mp.peca.nome }).to eq([ "Solado" ])
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
    it "returns pecas for a given modelo and client" do
      modelo = create(:modelo, nome: "Sapato")
      peca = create(:peca, nome: "Solado")
      client = create(:client, name: "Test Client", responsible: "John")
      create(:arquivo, modelo: modelo, peca: peca, client: client, organized: true)

      get for_cascade_pecas_path(modelo_uuid: modelo.uuid, client_uuid: client.uuid)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Solado")
    end

    it "returns pecas from organized arquivos regardless of tipo_corte" do
      modelo = create(:modelo)
      peca = create(:peca, nome: "Solado")
      create(:arquivo, tipo_corte: "apenas_corte", modelo: modelo, peca: peca, organized: true)

      get for_cascade_pecas_path(modelo_uuid: modelo.uuid)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Solado")
    end

    it "returns empty array when no organized arquivos exist" do
      modelo = create(:modelo)
      peca = create(:peca)

      get for_cascade_pecas_path(modelo_uuid: modelo.uuid)

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
    it "moves the peca to the trash" do
      peca = create(:peca, nome: "Solado")

      expect { delete peca_path(peca) }.not_to change(Peca, :count)
      expect(peca.reload).to be_excluido
    end
  end
end
