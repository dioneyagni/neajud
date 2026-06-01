require "rails_helper"

RSpec.describe "Clients", type: :request do
  describe "GET /clients" do
    it "renders the clients index page" do
      create(:client, name: "Alpha Corp", responsible: "Alice")
      create(:client, name: "Beta Inc", responsible: "Bob")

      get clients_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Alpha Corp")
      expect(response.body).to include("Beta Inc")
    end
  end

  describe "POST /clients" do
    it "creates a client with valid params" do
      expect {
        post clients_path, params: { client: { name: "Acme Corp", responsible: "John" } }
      }.to change(Client, :count).by(1)
      expect(response).to redirect_to(arquivos_path)
      expect(Client.last.name).to eq("Acme Corp")
    end

    it "rejects duplicate name (case-insensitive)" do
      create(:client, name: "Acme Corp", responsible: "Jane")
      expect {
        post clients_path, params: { client: { name: "ACME CORP", responsible: "Bob" } }
      }.not_to change(Client, :count)
      expect(response).to redirect_to(arquivos_path)
    end

    it "rejects blank name" do
      expect {
        post clients_path, params: { client: { name: "", responsible: "Bob" } }
      }.not_to change(Client, :count)
    end

    it "assigns client to arquivo when arquivo_uuid is provided" do
      arquivo = create(:arquivo)
      expect {
        post clients_path, params: { client: { name: "Assign Corp", responsible: "John" }, arquivo_uuid: arquivo.uuid }
      }.to change(Client, :count).by(1)
      arquivo.reload
      expect(arquivo.client_id).to eq(Client.last.id)
    end

    it "assigns existing client to arquivo on duplicate name with arquivo_uuid" do
      existing = create(:client, name: "Acme Corp", responsible: "Jane")
      arquivo = create(:arquivo)
      post clients_path, params: { client: { name: "ACME CORP", responsible: "Bob" }, arquivo_uuid: arquivo.uuid }
      arquivo.reload
      expect(arquivo.client_id).to eq(existing.id)
    end
  end

  describe "PATCH /clients/:id" do
    it "updates a client name and responsible" do
      client = create(:client, name: "Old Name", responsible: "Old Resp")
      patch client_path(client), params: { client: { name: "New Name", responsible: "New Resp" } }
      expect(response).to redirect_to(arquivos_path)
      client.reload
      expect(client.name).to eq("New Name")
      expect(client.responsible).to eq("New Resp")
    end
  end

  describe "DELETE /clients/:id" do
    it "destroys a client and nullifies arquivo references" do
      client = create(:client, name: "ToDelete", responsible: "Resp")
      arquivo = create(:arquivo, client: client)

      expect {
        delete client_path(client)
      }.to change(Client, :count).by(-1)

      expect(response).to redirect_to(arquivos_path)
      arquivo.reload
      expect(arquivo.client_id).to be_nil
    end
  end

  describe "GET /clients/:id" do
    it "renders the client show page" do
      client = create(:client, name: "Show Corp", responsible: "Tester")
      get client_path(client)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Show Corp")
      expect(response.body).to include("Details")
      expect(response.body).to include("Modelos")
    end

    it "returns 404 for nonexistent client" do
      get client_path(99999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /clients/search" do
    it "returns matching clients as JSON" do
      create(:client, name: "Alpha Corp", responsible: "Alice")
      create(:client, name: "Beta Inc", responsible: "Bob")
      create(:client, name: "Gamma LLC", responsible: "Charlie")

      get search_clients_path, params: { q: "Alpha" }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("Alpha Corp")
    end

    it "searches by responsible field" do
      create(:client, name: "Alpha Corp", responsible: "Alice Wonderland")
      get search_clients_path, params: { q: "Wonderland" }
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
    end
  end

  describe "PATCH /arquivos/:id/update_client" do
    it "assigns a client to an arquivo" do
      client = create(:client, name: "Test Client", responsible: "Test Resp")
      arquivo = create(:arquivo)
      patch update_client_arquivo_path(arquivo), params: { client_id: client.id }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.client_id).to eq(client.id)
    end

    it "unlinks a client from an arquivo" do
      client = create(:client, name: "Test Client", responsible: "Test Resp")
      arquivo = create(:arquivo, client: client)
      patch update_client_arquivo_path(arquivo), params: { client_id: "" }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.client_id).to be_nil
    end

    it "responds with turbo stream when requested" do
      client = create(:client, name: "Turbo Client", responsible: "Turbo Resp")
      arquivo = create(:arquivo)
      patch update_client_arquivo_path(arquivo), params: { client_id: client.id }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end
  end
end
