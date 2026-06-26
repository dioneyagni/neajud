require "rails_helper"

RSpec.describe MateriaPrima, type: :model do
  let(:grupo) { GrupoMaterial.find_or_create_by!(nome: "Oxford") }
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Azul") }

  subject(:mp) do
    described_class.new(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")
  end

  describe "validations" do
    it { should validate_presence_of(:largura) }
    it { should validate_presence_of(:gramatura) }
  end

  describe "associations" do
    it { should belong_to(:grupo_material) }
    it { should belong_to(:cor_material) }
    it { should have_many(:movimento_estoques).dependent(:restrict_with_error) }
  end

  describe "#nome_completo" do
    it "returns formatted name with group, color, width and weight" do
      expect(mp.nome_completo).to eq("Oxford-Azul-1.40-100g")
    end
  end

  describe "#saldo" do
    it "returns zero when no movements exist" do
      mp.save!
      expect(mp.saldo).to eq(0.0)
    end

    it "calculates entrada minus saida" do
      mp.save!
      mp.movimento_estoques.create!(client: create(:client), tipo: "entrada", quantidade: 10)
      mp.movimento_estoques.create!(client: create(:client), tipo: "saida", quantidade: 3)
      expect(mp.saldo).to eq(7.0)
    end

    it "accepts an optional cache" do
      cache = { mp.id => 15.0 }
      expect(mp.saldo(cache)).to eq(15.0)
    end
  end
end
