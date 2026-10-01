require "rails_helper"

RSpec.describe "Pecas", type: :request do
  describe "GET /pecas" do
    it "renders the index page, with the moldes that use each piece" do
      create(:molde, sufixo: "001-TNS").molde_pecas.create!(peca: create(:peca, nome: "Solado"))

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
      molde = create(:molde, sufixo: "001-TNS")

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

  # The pieces of the molde's own cortes (Arquivo.cortes_do_molde).
  describe "GET /pecas/for_cascade" do
    let(:molde) { create(:molde) }

    def corte(peca, molde: self.molde, **attrs)
      create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo, **attrs).tap { |c| c.moldes << molde }
    end

    it "lists the pieces of the cortes linked to the molde, regardless of tipo_corte" do
      corte(create(:peca, nome: "Solado"), tipo_corte: "apenas_corte")
      corte(create(:peca, nome: "Lateral"))
      get for_cascade_pecas_path(molde_uuid: molde.uuid)
      expect(response.parsed_body.map { |p| p["nome"] }).to eq(%w[Lateral Solado])
    end

    # Regression (01/10/2026): the molde moved to the official "Tenis" while
    # its cortes kept the old category — filtering by category listed nothing,
    # and the size couldn't be chosen.
    it "lists the molde's cortes even when they carry another category" do
      corte(create(:peca, nome: "Lateral"), modelo: create(:modelo, nome: "Tenis Baixo"))
      get for_cascade_pecas_path(molde_uuid: molde.uuid)
      expect(response.parsed_body.map { |p| p["nome"] }).to eq([ "Lateral" ])
    end

    # Another molde of the same client and category has its own cortes.
    it "doesn't list another molde's cortes" do
      corte(create(:peca, nome: "Lateral"))
      outro = create(:molde, client: molde.client, modelo: molde.modelo)
      corte(create(:peca, nome: "Furado"), molde: outro)
      get for_cascade_pecas_path(molde_uuid: molde.uuid)
      expect(response.parsed_body.map { |p| p["nome"] }).to eq([ "Lateral" ])
    end

    it "returns an empty array for an unknown molde" do
      get for_cascade_pecas_path(molde_uuid: "nao-existe")
      expect(response.parsed_body).to eq([])
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
