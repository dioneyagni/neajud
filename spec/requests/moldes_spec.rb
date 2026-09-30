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

    it "renders molde_pecas with corte status when modelo has pecas" do
      client = create(:client, name: "Test Client", responsible: "John")
      modelo = create(:modelo)
      peca1 = create(:peca, nome: "Frente")
      peca2 = create(:peca, nome: "Costa")
      ModeloPeca.create!(modelo: modelo, peca: peca1)
      ModeloPeca.create!(modelo: modelo, peca: peca2)

      molde = create(:molde, nome: "Camisa", client: client, modelo: modelo)
      molde.sync_molde_pecas!

      corte = create(:arquivo, :corte, filename: "frente.dxf", client: client, molde: molde,
                     modelo: modelo, peca: peca1, organized: true)

      get molde_path(molde)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Frente")
      expect(response.body).to include("Costa")
      expect(response.body).to include("frente.dxf")
      expect(response.body).to include("Corte ausente")
    end

    it "auto-syncs molde_pecas when modelo assigned but no records exist" do
      client = create(:client, name: "Test Client", responsible: "John")
      modelo = create(:modelo)
      peca = create(:peca, nome: "Manga")
      ModeloPeca.create!(modelo: modelo, peca: peca)

      molde = create(:molde, nome: "Regata", client: client, modelo: modelo)
      expect(molde.molde_pecas.count).to eq(0)

      get molde_path(molde)

      expect(response).to have_http_status(:success)
      expect(molde.reload.molde_pecas.count).to eq(1)
    end
  end

  describe "PATCH /moldes/:id/update_peca_config" do
    it "toggles needs_cut for a molde_peca" do
      client = create(:client, name: "Test Client", responsible: "John")
      modelo = create(:modelo)
      peca = create(:peca, nome: "Frente")
      ModeloPeca.create!(modelo: modelo, peca: peca)

      molde = create(:molde, nome: "Camisa", client: client, modelo: modelo)
      molde.sync_molde_pecas!
      mp = molde.molde_pecas.first

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

    # Regression (Etapa 1.1, 1/2): the "modelo changed?" check ran before the
    # new modelo was assigned, so it was always false and the pieces kept the
    # old modelo's list (the show page only syncs an empty list).
    it "rebuilds the pieces from the new modelo when the modelo changes" do
      antigo = create(:modelo).tap { |m| m.pecas << create(:peca, nome: "Lateral") }
      novo = create(:modelo).tap { |m| m.pecas << create(:peca, nome: "Cabedal") }
      molde = create(:molde, modelo: antigo).tap(&:sync_molde_pecas!)

      patch molde_path(molde), params: { molde: { modelo_uuid: novo.uuid } }

      expect(molde.reload.modelo).to eq(novo)
      expect(molde.molde_pecas.map { |mp| mp.peca.nome }).to eq([ "Cabedal" ])
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
