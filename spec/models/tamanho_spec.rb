require "rails_helper"

RSpec.describe Tamanho, type: :model do
  describe "validations" do
    it { should validate_presence_of(:nome) }
  end

  describe "associations" do
    it { should belong_to(:arquivo) }
  end

  describe "default scope" do
    it "orders by position" do
      arquivo = create(:arquivo)
      second = Tamanho.create!(nome: "G", position: 2, arquivo: arquivo)
      first = Tamanho.create!(nome: "P", position: 1, arquivo: arquivo)
      expect(Tamanho.where(arquivo: arquivo).to_a).to eq([ first, second ])
    end
  end

  describe "#atende_rotulo? (Etapa 1.2, 2/3)" do
    it "serves the numbers it covers, or its own label" do
      par = build(:tamanho, nome: "29-30", numeros: %w[29 30])
      pmg = build(:tamanho, nome: "P", numeros: %w[33 34])
      expect(%w[30 29-30 31].map { |r| par.atende_rotulo?(r) }).to eq([ true, true, false ])
      expect(%w[p 33 M].map { |r| pmg.atende_rotulo?(r) }).to eq([ true, true, false ])
    end

    it "matches a legacy size without numbers only by name" do
      expect(build(:tamanho, nome: "30", numeros: []).atende_rotulo?("30")).to be true
    end
  end
end
