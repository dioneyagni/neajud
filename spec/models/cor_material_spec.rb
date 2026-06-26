require "rails_helper"

RSpec.describe CorMaterial, type: :model do
  describe "validations" do
    subject { CorMaterial.new(nome: "Test Color #{Time.now.to_i}") }
    it { should validate_presence_of(:nome) }
    it { should validate_uniqueness_of(:nome).case_insensitive }
  end

  describe "associations" do
    it { should have_many(:materia_primas).dependent(:restrict_with_error) }
  end

  describe "COLOR_HEX" do
    it "defines hex values for common colors" do
      expect(described_class::COLOR_HEX["Branco"]).to eq("#FFFFFF")
      expect(described_class::COLOR_HEX["Preto"]).to eq("#000000")
      expect(described_class::COLOR_HEX["Azul"]).to eq("#0000FF")
    end
  end
end
