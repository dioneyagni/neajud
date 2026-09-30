require "rails_helper"

RSpec.describe "Modelos", type: :request do
  describe "GET /modelos" do
    it "renders the index page" do
      create(:modelo, nome: "Sapato")

      get modelos_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sapato")
    end
  end

  describe "GET /modelos/:id" do
    it "renders the show page" do
      modelo = create(:modelo, nome: "Sapato")

      get modelo_path(modelo)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sapato")
    end
  end

  describe "GET /modelos/new" do
    it "renders the new page" do
      get new_modelo_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Register New Modelo")
      expect(response.body).to include("Componentes")
    end
  end

  describe "GET /modelos/:id/edit" do
    it "renders the edit page" do
      modelo = create(:modelo, nome: "Sapato")

      get edit_modelo_path(modelo)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit Modelo")
    end

    # Leaving a trashed peça out of the checkboxes would unlink it on save.
    it "lists active peças plus the trashed ones this modelo already has" do
      linked = create(:peca, nome: "Linked trashed")
      create(:peca, nome: "Other trashed").excluir!(changed_by: "10.0.0.1")
      modelo = create(:modelo).tap { |m| m.pecas << linked }
      linked.excluir!(changed_by: "10.0.0.1")

      get edit_modelo_path(modelo)

      expect(response.body).to include("Linked trashed")
      expect(response.body).not_to include("Other trashed")
    end
  end

  describe "POST /modelos" do
    it "creates a modelo with valid params" do
      expect {
        post modelos_path, params: { modelo: { nome: "Sapato" } }
      }.to change(Modelo, :count).by(1)

      expect(Modelo.last.nome).to eq("Sapato")
    end

    it "links the peças listed by uuid" do
      lateral = create(:peca, nome: "Lateral")
      post modelos_path, params: { modelo: { nome: "Tenis", peca_uuids: [ lateral.uuid ] } }
      expect(Modelo.last.pecas).to eq([ lateral ])
    end

    it "redirects to modelo show page on success" do
      post modelos_path, params: { modelo: { nome: "Chinelo" } }

      expect(response).to redirect_to(modelo_path(Modelo.last))
    end

    it "renders new on validation failure" do
      post modelos_path, params: { modelo: { nome: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Register New Modelo")
    end
  end

  describe "GET /modelos/search" do
    it "returns matching modelos as JSON" do
      create(:modelo, nome: "Sapato")

      get search_modelos_path, params: { q: "Sap" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Sapato")
    end
  end

  describe "GET /modelos/:id/pecas" do
    it "returns pecas for a modelo" do
      modelo = create(:modelo, nome: "Sapato")
      peca = create(:peca, nome: "Solado")
      modelo.pecas << peca

      get pecas_modelo_path(modelo)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Solado")
    end
  end

  describe "PATCH /modelos/:id" do
    it "updates a modelo" do
      modelo = create(:modelo, nome: "Sapato")

      patch modelo_path(modelo), params: { modelo: { nome: "Chinelo" } }

      modelo.reload
      expect(modelo.nome).to eq("Chinelo")
    end

    it "replaces the peças with the ones listed by uuid" do
      modelo = create(:modelo).tap { |m| m.pecas << create(:peca, nome: "Lateral") }
      lingua = create(:peca, nome: "Língua")
      patch modelo_path(modelo), params: { modelo: { nome: modelo.nome, peca_uuids: [ "", lingua.uuid ] } }
      expect(modelo.reload.pecas).to eq([ lingua ])
    end
  end

  describe "DELETE /modelos/:id" do
    it "moves the modelo to the trash, keeping its peças" do
      modelo = create(:modelo, nome: "Sapato")
      modelo.pecas << create(:peca)

      expect { delete modelo_path(modelo) }.not_to change(Modelo, :count)
      expect(modelo.reload).to be_excluido
      expect(modelo.pecas.count).to eq(1)
    end
  end
end
