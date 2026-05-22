require "rails_helper"

RSpec.describe Molde do
  it "is valid with a unique nome" do
    molde = Molde.new(nome: "Sapato")
    expect(molde).to be_valid
  end

  it "is invalid without a nome" do
    molde = Molde.new(nome: nil)
    expect(molde).not_to be_valid
  end

  it "is invalid with a duplicate nome" do
    Molde.create!(nome: "Sapato")
    duplicate = Molde.new(nome: "Sapato")
    expect(duplicate).not_to be_valid
  end

  it "is invalid with a case-insensitive duplicate nome" do
    Molde.create!(nome: "Sapato")
    duplicate = Molde.new(nome: "SAPATO")
    expect(duplicate).not_to be_valid
  end

  describe ".search" do
    it "returns moldes matching the query" do
      molde = Molde.create!(nome: "Sapato")
      Molde.create!(nome: "Chinelo")
      expect(Molde.search("Sap")).to include(molde)
    end

    it "returns all moldes when query is blank" do
      expect(Molde.search("").count).to eq(Molde.count)
    end
  end
end
