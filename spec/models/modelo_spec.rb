require "rails_helper"

RSpec.describe Modelo do
  it "is valid with a unique nome" do
    modelo = Modelo.new(nome: "Sapato")
    expect(modelo).to be_valid
  end

  it "is invalid without a nome" do
    modelo = Modelo.new(nome: nil)
    expect(modelo).not_to be_valid
  end

  it "is invalid with a duplicate nome" do
    Modelo.create!(nome: "Sapato")
    duplicate = Modelo.new(nome: "Sapato")
    expect(duplicate).not_to be_valid
  end

  it "is invalid with a case-insensitive duplicate nome" do
    Modelo.create!(nome: "Sapato")
    duplicate = Modelo.new(nome: "SAPATO")
    expect(duplicate).not_to be_valid
  end

  describe ".search" do
    it "returns modelos matching the query" do
      modelo = Modelo.create!(nome: "Sapato")
      Modelo.create!(nome: "Chinelo")
      expect(Modelo.search("Sap")).to include(modelo)
    end

    it "returns all modelos when query is blank" do
      expect(Modelo.search("").count).to eq(Modelo.count)
    end
  end
end
