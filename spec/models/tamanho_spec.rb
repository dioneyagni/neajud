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
end
