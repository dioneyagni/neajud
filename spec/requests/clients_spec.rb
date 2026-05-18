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
      expect(response).to redirect_to(stamps_path)
      expect(Client.last.name).to eq("Acme Corp")
    end

    it "rejects duplicate name (case-insensitive)" do
      create(:client, name: "Acme Corp", responsible: "Jane")
      expect {
        post clients_path, params: { client: { name: "ACME CORP", responsible: "Bob" } }
      }.not_to change(Client, :count)
      expect(response).to redirect_to(stamps_path)
    end

    it "rejects blank name" do
      expect {
        post clients_path, params: { client: { name: "", responsible: "Bob" } }
      }.not_to change(Client, :count)
    end

    it "assigns client to stamp when stamp_uuid is provided" do
      stamp = create(:stamp)
      expect {
        post clients_path, params: { client: { name: "Assign Corp", responsible: "John" }, stamp_uuid: stamp.uuid }
      }.to change(Client, :count).by(1)
      stamp.reload
      expect(stamp.client_id).to eq(Client.last.id)
    end

    it "assigns existing client to stamp on duplicate name with stamp_uuid" do
      existing = create(:client, name: "Acme Corp", responsible: "Jane")
      stamp = create(:stamp)
      post clients_path, params: { client: { name: "ACME CORP", responsible: "Bob" }, stamp_uuid: stamp.uuid }
      stamp.reload
      expect(stamp.client_id).to eq(existing.id)
    end
  end

  describe "PATCH /clients/:id" do
    it "updates a client name and responsible" do
      client = create(:client, name: "Old Name", responsible: "Old Resp")
      patch client_path(client), params: { client: { name: "New Name", responsible: "New Resp" } }
      expect(response).to redirect_to(stamps_path)
      client.reload
      expect(client.name).to eq("New Name")
      expect(client.responsible).to eq("New Resp")
    end
  end

  describe "DELETE /clients/:id" do
    it "destroys a client and nullifies stamp references" do
      client = create(:client, name: "ToDelete", responsible: "Resp")
      stamp = create(:stamp, client: client)

      expect {
        delete client_path(client)
      }.to change(Client, :count).by(-1)

      expect(response).to redirect_to(stamps_path)
      stamp.reload
      expect(stamp.client_id).to be_nil
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

  describe "PATCH /stamps/:id/update_client" do
    it "assigns a client to a stamp" do
      client = create(:client, name: "Test Client", responsible: "Test Resp")
      stamp = create(:stamp)
      patch update_client_stamp_path(stamp.uuid), params: { client_id: client.id }
      expect(response).to redirect_to(stamp_path(stamp))
      stamp.reload
      expect(stamp.client_id).to eq(client.id)
    end

    it "unlinks a client from a stamp" do
      client = create(:client, name: "Test Client", responsible: "Test Resp")
      stamp = create(:stamp, client: client)
      patch update_client_stamp_path(stamp.uuid), params: { client_id: "" }
      expect(response).to redirect_to(stamp_path(stamp))
      stamp.reload
      expect(stamp.client_id).to be_nil
    end
  end
end
