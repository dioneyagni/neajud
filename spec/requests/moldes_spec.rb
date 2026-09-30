require "rails_helper"

RSpec.describe "Moldes", type: :request do
  describe "GET /moldes" do
    it "renders the index page" do
      client = create(:client, name: "Test Client", responsible: "John")
      create(:molde, nome: "Air Max", client: client)

      get moldes_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Air Max")
    end
  end

  describe "GET /moldes/:id" do
    it "renders the show page" do
      client = create(:client, name: "Test Client", responsible: "John")
      molde = create(:molde, nome: "Air Max", client: client)

      get molde_path(molde)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Air Max")
    end

    it "renders the molde's own parts with their corte status" do
      client = create(:client, name: "Test Client", responsible: "John")
      modelo = create(:modelo)
      peca1 = create(:peca, nome: "Frente")
      peca2 = create(:peca, nome: "Costa")

      molde = create(:molde, nome: "Camisa", client: client, modelo: modelo)
      molde.molde_pecas.create!(peca: peca1)
      molde.molde_pecas.create!(peca: peca2)

      corte = create(:arquivo, :corte, filename: "frente.dxf", client: client, molde: molde,
                     modelo: modelo, peca: peca1, organized: true)

      get molde_path(molde)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Frente")
      expect(response.body).to include("Costa")
      expect(response.body).to include("frente.dxf")
      expect(response.body).to include("Corte ausente")
    end

    # Etapa 1.1 (3/5): a category has no parts, so nothing is copied from it.
    it "shows a molde without parts as such, and offers the company's pieces" do
      create(:peca, nome: "Manga")
      molde = create(:molde, modelo: create(:modelo))
      get molde_path(molde)
      expect(molde.reload.molde_pecas).to be_empty
      expect(response.body).to include("This molde has no parts yet.", %(<option value="#{Peca.last.uuid}">Manga</option>))
    end

    it "shows the stretch of the grade the molde uses" do
      molde = create(:molde, modelo: create(:modelo), tamanho_inicial: "24", tamanho_final: "34")
      get molde_path(molde)
      expect(response.body).to include("24–34")
    end
  end

  describe "the molde's parts (Etapa 1.1, 3/5)" do
    let(:molde) { create(:molde) }
    let(:lateral) { create(:peca, nome: "Lateral") }

    it "adds a part from the company's piece list" do
      post adicionar_parte_molde_path(molde), params: { peca_uuid: lateral.uuid }
      expect(molde.molde_pecas.map(&:peca)).to eq([ lateral ])
      expect(flash[:notice]).to eq("Part \"Lateral\" added.")
    end

    it "refuses the same part twice and a trashed piece" do
      molde.molde_pecas.create!(peca: lateral)
      post adicionar_parte_molde_path(molde), params: { peca_uuid: lateral.uuid }
      expect(flash[:alert]).to include("Could not add \"Lateral\"")
      lateral.excluir!(changed_by: "10.0.0.1")
      post adicionar_parte_molde_path(create(:molde)), params: { peca_uuid: lateral.uuid }
      expect(response).to have_http_status(:not_found)
    end

    it "removes a part" do
      parte = molde.molde_pecas.create!(peca: lateral)
      delete remover_parte_molde_path(molde, molde_peca_uuid: parte.uuid)
      expect(molde.molde_pecas.reload).to be_empty
    end
  end

  describe "PATCH /moldes/:id/update_peca_config" do
    it "toggles needs_cut for a molde_peca" do
      client = create(:client, name: "Test Client", responsible: "John")
      peca = create(:peca, nome: "Frente")

      molde = create(:molde, nome: "Camisa", client: client, modelo: create(:modelo))
      mp = molde.molde_pecas.create!(peca: peca)

      expect(mp.needs_cut).to be true

      patch update_peca_config_molde_path(molde), params: { molde_peca_uuid: mp.uuid, needs_cut: "false" }

      expect(response).to redirect_to(molde_path(molde))
      expect(mp.reload.needs_cut).to be false
    end
  end

  describe "POST /moldes" do
    it "creates a molde with valid params" do
      client = create(:client, name: "Test Client", responsible: "John")

      expect {
        post moldes_path, params: { molde: { nome: "Air Max", client_uuid: client.uuid } }
      }.to change(Molde, :count).by(1)

      expect(Molde.last.nome).to eq("Air Max")
    end
  end

  describe "GET /moldes/search" do
    it "returns matching moldes as JSON" do
      client = create(:client, name: "Test Client", responsible: "John")
      create(:molde, nome: "Air Max", client: client)

      get search_moldes_path, params: { q: "Air" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["nome"]).to eq("Air Max")
    end
  end

  # Regression (29/09/2026): a molde whose client went to the trash had no
  # option in the edit dialog's required select, so saving it was silently
  # blocked by the browser.
  it "offers a listed molde's trashed client in the edit dialog, marked" do
    client = create(:client, name: "Cliente Antigo")
    create(:molde, client: client)
    client.excluir!(changed_by: "10.0.0.1")
    create(:client, name: "Outro Na Lixeira", deleted_at: 1.day.ago)
    get moldes_path
    expect(response.body).to include("Cliente Antigo (in the trash)")
    expect(response.body).not_to include("Outro Na Lixeira")
  end

  describe "GET /moldes/for_client" do
    it "returns moldes for a given client" do
      client = create(:client, name: "Test Client", responsible: "John")
      create(:molde, nome: "Air Max", client: client)

      get for_client_moldes_path(client_uuid: client.uuid)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
    end
  end

  describe "PATCH /moldes/:id" do
    it "updates a molde" do
      client = create(:client, name: "Test Client", responsible: "John")
      molde = create(:molde, nome: "Air Max", client: client)

      patch molde_path(molde), params: { molde: { nome: "Air Max 2" } }

      molde.reload
      expect(molde.nome).to eq("Air Max 2")
    end

    it "saves the stretch of the grade and refuses one outside it" do
      molde = create(:molde, modelo: create(:modelo))
      patch molde_path(molde), params: { molde: { tamanho_inicial: "24", tamanho_final: "34" } }
      expect(molde.reload.grade.values_at(0, -1)).to eq(%w[24 34])
      patch molde_path(molde), params: { molde: { tamanho_inicial: "34", tamanho_final: "24" } }
      expect(flash[:alert]).to include("is not a stretch of 18–46")
      expect(molde.reload.tamanho_inicial).to eq("24")
    end

    # The copy of the category's pieces on a modelo change (Etapa 1.1, 1/2)
    # is gone with the category's pieces themselves (3/5).
    it "keeps the molde's parts when the modelo changes" do
      molde = create(:molde, modelo: create(:modelo))
      molde.molde_pecas.create!(peca: create(:peca, nome: "Lateral"))
      patch molde_path(molde), params: { molde: { modelo_uuid: create(:modelo).uuid } }
      expect(molde.reload.molde_pecas.map { |mp| mp.peca.nome }).to eq([ "Lateral" ])
    end
  end

  describe "DELETE /moldes/:id" do
    it "moves the molde to the trash" do
      client = create(:client, name: "Test Client", responsible: "John")
      molde = create(:molde, nome: "Air Max", client: client)

      expect { delete molde_path(molde) }.not_to change(Molde, :count)
      expect(molde.reload).to be_excluido
    end

    # Regression (29/09/2026): the arte page's combobox appended "?q=" to a URL
    # that already had "?client_id=", and for_client ignored q anyway.
    it "for_client filters by the typed text" do
      client = create(:client)
      create(:molde, client: client, nome: "001-JGG INF")
      create(:molde, client: client, nome: "002-JGG NB")
      get for_client_moldes_path(client_uuid: client.uuid, q: "inf")
      expect(response.parsed_body.map { |m| m["nome"] }).to eq([ "001-JGG INF" ])
    end

    it "hides trashed moldes from for_client" do
      molde = create(:molde, deleted_at: 1.day.ago)
      get for_client_moldes_path(client_id: molde.client_id)
      expect(response.parsed_body).to eq([])
    end
  end
end
