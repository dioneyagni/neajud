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

  describe "GET /moldes/new" do
    it "renders the new page" do
      get new_molde_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Register New Molde")
      expect(response.body).to include("Componentes")
    end
  end

  describe "GET /moldes/:id/edit" do
    it "renders the edit page" do
      molde = create(:molde, nome: "Sapato")

      get edit_molde_path(molde)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit Molde")
    end

    # Leaving a trashed peça out of the checkboxes would unlink it on save.
    it "lists active peças plus the trashed ones this molde already has" do
      linked = create(:peca, nome: "Linked trashed")
      create(:peca, nome: "Other trashed").excluir!(changed_by: "10.0.0.1")
      molde = create(:molde).tap { |m| m.pecas << linked }
      linked.excluir!(changed_by: "10.0.0.1")

      get edit_molde_path(molde)

      expect(response.body).to include("Linked trashed")
      expect(response.body).not_to include("Other trashed")
    end
  end

  describe "POST /moldes" do
    it "creates a molde with valid params" do
      expect {
        post moldes_path, params: { molde: { nome: "Sapato" } }
      }.to change(Molde, :count).by(1)

      expect(Molde.last.nome).to eq("Sapato")
    end

    it "links the peças listed by uuid" do
      lateral = create(:peca, nome: "Lateral")
      post moldes_path, params: { molde: { nome: "Tenis", peca_uuids: [ lateral.uuid ] } }
      expect(Molde.last.pecas).to eq([ lateral ])
    end

    it "redirects to molde show page on success" do
      post moldes_path, params: { molde: { nome: "Chinelo" } }

      expect(response).to redirect_to(molde_path(Molde.last))
    end

    it "renders new on validation failure" do
      post moldes_path, params: { molde: { nome: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Register New Molde")
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

    it "replaces the peças with the ones listed by uuid" do
      molde = create(:molde).tap { |m| m.pecas << create(:peca, nome: "Lateral") }
      lingua = create(:peca, nome: "Língua")
      patch molde_path(molde), params: { molde: { nome: molde.nome, peca_uuids: [ "", lingua.uuid ] } }
      expect(molde.reload.pecas).to eq([ lingua ])
    end
  end

  describe "DELETE /moldes/:id" do
    it "moves the molde to the trash, keeping its peças" do
      molde = create(:molde, nome: "Sapato")
      molde.pecas << create(:peca)

      expect { delete molde_path(molde) }.not_to change(Molde, :count)
      expect(molde.reload).to be_excluido
      expect(molde.pecas.count).to eq(1)
    end
  end
end
