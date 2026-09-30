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

      patch update_peca_config_modelo_path(modelo), params: { modelo_peca_uuid: mp.uuid, needs_cut: "false" }

      expect(response).to redirect_to(modelo_path(modelo))
      expect(mp.reload.needs_cut).to be false
    end
  end

  describe "POST /modelos" do
    it "creates a modelo with valid params" do
      client = create(:client, name: "Test Client", responsible: "John")

      expect {
        post modelos_path, params: { modelo: { nome: "Air Max", client_uuid: client.uuid } }
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

  # Regression (29/09/2026): a modelo whose client went to the trash had no
  # option in the edit dialog's required select, so saving it was silently
  # blocked by the browser.
  it "offers a listed modelo's trashed client in the edit dialog, marked" do
    client = create(:client, name: "Cliente Antigo")
    create(:modelo, client: client)
    client.excluir!(changed_by: "10.0.0.1")
    create(:client, name: "Outro Na Lixeira", deleted_at: 1.day.ago)
    get modelos_path
    expect(response.body).to include("Cliente Antigo (in the trash)")
    expect(response.body).not_to include("Outro Na Lixeira")
  end

  describe "GET /modelos/for_client" do
    it "returns modelos for a given client" do
      client = create(:client, name: "Test Client", responsible: "John")
      create(:modelo, nome: "Air Max", client: client)

      get for_client_modelos_path(client_uuid: client.uuid)

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

    # Regression (Etapa 1.1, 1/2): the "molde changed?" check ran before the
    # new molde was assigned, so it was always false and the pieces kept the
    # old molde's list (the show page only syncs an empty list).
    it "rebuilds the pieces from the new molde when the molde changes" do
      antigo = create(:molde).tap { |m| m.pecas << create(:peca, nome: "Lateral") }
      novo = create(:molde).tap { |m| m.pecas << create(:peca, nome: "Cabedal") }
      modelo = create(:modelo, molde: antigo).tap(&:sync_modelo_pecas!)

      patch modelo_path(modelo), params: { modelo: { molde_uuid: novo.uuid } }

      expect(modelo.reload.molde).to eq(novo)
      expect(modelo.modelo_pecas.map { |mp| mp.peca.nome }).to eq([ "Cabedal" ])
    end
  end

  describe "DELETE /modelos/:id" do
    it "moves the modelo to the trash" do
      client = create(:client, name: "Test Client", responsible: "John")
      modelo = create(:modelo, nome: "Air Max", client: client)

      expect { delete modelo_path(modelo) }.not_to change(Modelo, :count)
      expect(modelo.reload).to be_excluido
    end

    # Regression (29/09/2026): the arte page's combobox appended "?q=" to a URL
    # that already had "?client_id=", and for_client ignored q anyway.
    it "for_client filters by the typed text" do
      client = create(:client)
      create(:modelo, client: client, nome: "001-JGG INF")
      create(:modelo, client: client, nome: "002-JGG NB")
      get for_client_modelos_path(client_uuid: client.uuid, q: "inf")
      expect(response.parsed_body.map { |m| m["nome"] }).to eq([ "001-JGG INF" ])
    end

    it "hides trashed modelos from for_client" do
      modelo = create(:modelo, deleted_at: 1.day.ago)
      get for_client_modelos_path(client_id: modelo.client_id)
      expect(response.parsed_body).to eq([])
    end
  end
end
