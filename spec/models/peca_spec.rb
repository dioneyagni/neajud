require "rails_helper"

RSpec.describe Peca do
  it "is valid with a unique nome" do
    peca = Peca.new(nome: "Test Peca Unique #{Time.now.to_i}")
    expect(peca).to be_valid
  end

  it "is invalid without a nome" do
    peca = Peca.new(nome: nil)
    expect(peca).not_to be_valid
  end

  it "is invalid with a duplicate nome" do
    Peca.where(nome: "Test Peca Dup").destroy_all
    Peca.create!(nome: "Test Peca Dup")
    duplicate = Peca.new(nome: "Test Peca Dup")
    expect(duplicate).not_to be_valid
  end

  it "is invalid with a case-insensitive duplicate nome" do
    Peca.where(nome: "Test Peca Case").destroy_all
    Peca.create!(nome: "Test Peca Case")
    duplicate = Peca.new(nome: "TEST PECA CASE")
    expect(duplicate).not_to be_valid
  end

  describe ".search" do
    it "returns pecas matching the query" do
      Peca.where(nome: "Test Peca Search").destroy_all
      peca = Peca.create!(nome: "Test Peca Search")
      expect(Peca.search("Test Peca Search")).to include(peca)
    end
  end
end
