require "rails_helper"

RSpec.describe Modelo do
  it "is valid with nome and client" do
    client = Client.create!(name: "Test Client", responsible: "John")
    modelo = Modelo.new(nome: "Air Max", client: client)
    expect(modelo).to be_valid
  end

  it "is invalid without a nome" do
    client = Client.create!(name: "Test Client", responsible: "John")
    modelo = Modelo.new(nome: nil, client: client)
    expect(modelo).not_to be_valid
  end

  it "is invalid without a client" do
    modelo = Modelo.new(nome: "Air Max")
    expect(modelo).not_to be_valid
  end

  it "allows same nome for different clients" do
    client1 = Client.create!(name: "Client A", responsible: "A")
    client2 = Client.create!(name: "Client B", responsible: "B")
    Modelo.create!(nome: "Classic", client: client1)
    modelo2 = Modelo.new(nome: "Classic", client: client2)
    expect(modelo2).to be_valid
  end

  it "is invalid with duplicate nome for same client" do
    client = Client.create!(name: "Test Client", responsible: "John")
    Modelo.create!(nome: "Classic", client: client)
    duplicate = Modelo.new(nome: "Classic", client: client)
    expect(duplicate).not_to be_valid
  end

  describe ".for_client" do
    it "returns modelos for a given client" do
      client = Client.create!(name: "Test Client", responsible: "John")
      modelo = Modelo.create!(nome: "Air Max", client: client)
      expect(Modelo.for_client(client.id)).to include(modelo)
    end
  end

  describe ".search" do
    it "returns modelos matching the query" do
      client = Client.create!(name: "Test Client", responsible: "John")
      modelo = Modelo.create!(nome: "Air Max", client: client)
      expect(Modelo.search("Air")).to include(modelo)
    end
  end

  describe "#sync_modelo_pecas!" do
    let(:client) { Client.create!(name: "Test Client", responsible: "John") }
    let(:molde) { Molde.create!(nome: "Molde Base") }
    let(:peca1) { Peca.create!(nome: "Frente") }
    let(:peca2) { Peca.create!(nome: "Costa") }

    before do
      MoldePeca.create!(molde: molde, peca: peca1)
      MoldePeca.create!(molde: molde, peca: peca2)
    end

    it "creates modelo_pecas for all molde pecas" do
      modelo = Modelo.create!(nome: "Camisa", client: client, molde: molde)
      modelo.sync_modelo_pecas!

      expect(modelo.modelo_pecas.count).to eq(2)
      expect(modelo.configured_pecas.pluck(:nome)).to contain_exactly("Frente", "Costa")
    end

    it "does not duplicate existing records" do
      modelo = Modelo.create!(nome: "Camisa", client: client, molde: molde)
      modelo.sync_modelo_pecas!
      modelo.sync_modelo_pecas!

      expect(modelo.modelo_pecas.count).to eq(2)
    end

    it "removes modelo_pecas for pecas no longer in the molde" do
      modelo = Modelo.create!(nome: "Camisa", client: client, molde: molde)
      modelo.sync_modelo_pecas!

      MoldePeca.where(molde_id: molde.id, peca_id: peca2.id).delete_all
      modelo.sync_modelo_pecas!

      expect(modelo.modelo_pecas.count).to eq(1)
      expect(modelo.configured_pecas.pluck(:nome)).to eq([ "Frente" ])
    end

    it "does nothing when molde_id is nil" do
      modelo = Modelo.create!(nome: "Avulso", client: client)
      modelo.sync_modelo_pecas!

      expect(modelo.modelo_pecas.count).to eq(0)
    end
  end
end
