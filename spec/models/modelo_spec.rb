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
end
