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

  # Etapa 1.1 (3/5): the molde uses a stretch of its produto's grade; its
  # parts are its own (no copy from the category any more).
  describe "grade interval" do
    let(:client) { create(:client) }
    let(:calcado) { create(:modelo, produto: create(:produto, grade: (18..46).map(&:to_s))) }
    let(:banner) { create(:modelo, produto: create(:produto, grade: [])) }

    def molde(modelo: calcado, de: nil, ate: nil)
      Molde.new(nome: "001-TNS", client: client, modelo: modelo, tamanho_inicial: de, tamanho_final: ate)
    end

    it "accepts a stretch of the produto's grade and lists it" do
      m = molde(de: "24", ate: "27")
      expect(m).to be_valid
      expect(m.grade).to eq(%w[24 25 26 27])
    end

    it "accepts no interval at all (chosen later)" do
      expect(molde).to be_valid
      expect(molde.grade).to eq([])
    end

    it "refuses sizes outside the grade, a reversed stretch, or only one end" do
      expect(molde(de: "17", ate: "20")).not_to be_valid
      reverso = molde(de: "30", ate: "24")
      expect(reverso).not_to be_valid
      expect(reverso.errors[:tamanho_final].first).to include("\"30\"–\"24\" is not a stretch of 18–46")
      expect(molde(de: "24")).not_to be_valid
    end

    it "refuses an interval when the produto has no grade (Banner)" do
      m = molde(modelo: banner, de: "P", ate: "G")
      expect(m).not_to be_valid
      expect(m.errors[:tamanho_inicial].first).to include("has none")
    end
  end
end
