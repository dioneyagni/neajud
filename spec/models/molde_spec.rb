require "rails_helper"

RSpec.describe Molde do
  it "is valid with nome and client" do
    client = Client.create!(name: "Test Client", responsible: "John")
    molde = Molde.new(nome: "Air Max", client: client)
    expect(molde).to be_valid
  end

  it "is invalid without a nome" do
    client = Client.create!(name: "Test Client", responsible: "John")
    molde = Molde.new(nome: nil, client: client)
    expect(molde).not_to be_valid
  end

  it "is invalid without a client" do
    molde = Molde.new(nome: "Air Max")
    expect(molde).not_to be_valid
  end

  it "allows same nome for different clients" do
    client1 = Client.create!(name: "Client A", responsible: "A")
    client2 = Client.create!(name: "Client B", responsible: "B")
    Molde.create!(nome: "Classic", client: client1)
    molde2 = Molde.new(nome: "Classic", client: client2)
    expect(molde2).to be_valid
  end

  it "is invalid with duplicate nome for same client" do
    client = Client.create!(name: "Test Client", responsible: "John")
    Molde.create!(nome: "Classic", client: client)
    duplicate = Molde.new(nome: "Classic", client: client)
    expect(duplicate).not_to be_valid
  end

  describe ".for_client" do
    it "returns moldes for a given client" do
      client = Client.create!(name: "Test Client", responsible: "John")
      molde = Molde.create!(nome: "Air Max", client: client)
      expect(Molde.for_client(client.id)).to include(molde)
    end
  end

  describe ".search" do
    it "returns moldes matching the query" do
      client = Client.create!(name: "Test Client", responsible: "John")
      molde = Molde.create!(nome: "Air Max", client: client)
      expect(Molde.search("Air")).to include(molde)
    end
  end

  describe "#sync_molde_pecas!" do
    let(:client) { Client.create!(name: "Test Client", responsible: "John") }
    let(:modelo) { Modelo.create!(nome: "Modelo Base") }
    let(:peca1) { Peca.create!(nome: "Frente") }
    let(:peca2) { Peca.create!(nome: "Costa") }

    before do
      ModeloPeca.create!(modelo: modelo, peca: peca1)
      ModeloPeca.create!(modelo: modelo, peca: peca2)
    end

    it "creates molde_pecas for all modelo pecas" do
      molde = Molde.create!(nome: "Camisa", client: client, modelo: modelo)
      molde.sync_molde_pecas!

      expect(molde.molde_pecas.count).to eq(2)
      expect(molde.configured_pecas.pluck(:nome)).to contain_exactly("Frente", "Costa")
    end

    it "keeps a trashed peça's row (and needs_cut) but never creates one for it" do
      molde = Molde.create!(nome: "Camisa", client: client, modelo: modelo)
      molde.sync_molde_pecas!
      molde.molde_pecas.find_by(peca: peca2).update!(needs_cut: false)
      peca2.excluir!(changed_by: "10.0.0.1")

      molde.sync_molde_pecas!
      expect(molde.molde_pecas.find_by(peca: peca2).needs_cut).to be false

      novo = Molde.create!(nome: "Blusa", client: client, modelo: modelo)
      novo.sync_molde_pecas!
      expect(novo.configured_pecas.pluck(:nome)).to eq([ "Frente" ])
    end

    it "does not duplicate existing records" do
      molde = Molde.create!(nome: "Camisa", client: client, modelo: modelo)
      molde.sync_molde_pecas!
      molde.sync_molde_pecas!

      expect(molde.molde_pecas.count).to eq(2)
    end

    it "removes molde_pecas for pecas no longer in the modelo" do
      molde = Molde.create!(nome: "Camisa", client: client, modelo: modelo)
      molde.sync_molde_pecas!

      ModeloPeca.where(modelo_id: modelo.id, peca_id: peca2.id).delete_all
      molde.sync_molde_pecas!

      expect(molde.molde_pecas.count).to eq(1)
      expect(molde.configured_pecas.pluck(:nome)).to eq([ "Frente" ])
    end

    it "does nothing when modelo_id is nil" do
      molde = Molde.create!(nome: "Avulso", client: client)
      molde.sync_molde_pecas!

      expect(molde.molde_pecas.count).to eq(0)
    end
  end
end
