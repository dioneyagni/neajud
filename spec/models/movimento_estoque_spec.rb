require "rails_helper"

RSpec.describe MovimentoEstoque, type: :model do
  describe "validations" do
    it { should validate_presence_of(:tipo) }
    it { should validate_presence_of(:quantidade) }
    it { should validate_numericality_of(:quantidade).is_greater_than(0) }
  end

  describe "associations" do
    it { should belong_to(:materia_prima) }
    it { should belong_to(:client) }
  end

  describe "scopes" do
    let(:client) { create(:client) }
    let(:grupo) { GrupoMaterial.find_or_create_by!(nome: "Oxford") }
    let(:cor) { CorMaterial.find_or_create_by!(nome: "Azul") }
    let(:mp) { MateriaPrima.create!(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g") }

    it ".entradas filters entrada movements" do
      mov = MovimentoEstoque.create!(client: client, materia_prima: mp, tipo: "entrada", quantidade: 5)
      expect(MovimentoEstoque.entradas).to include(mov)
      expect(MovimentoEstoque.saidas).not_to include(mov)
    end

    it ".saidas filters saida movements" do
      mov = MovimentoEstoque.create!(client: client, materia_prima: mp, tipo: "saida", quantidade: 3)
      expect(MovimentoEstoque.saidas).to include(mov)
      expect(MovimentoEstoque.entradas).not_to include(mov)
    end

    it ".recentes orders by created_at desc" do
      old = MovimentoEstoque.create!(client: client, materia_prima: mp, tipo: "entrada", quantidade: 1, created_at: 2.days.ago)
      new = MovimentoEstoque.create!(client: client, materia_prima: mp, tipo: "entrada", quantidade: 2, created_at: 1.day.ago)
      expect(MovimentoEstoque.where(materia_prima: mp).recentes.to_a).to eq([ new, old ])
    end
  end

  describe "#valor_total" do
    it "returns nil when valor is nil" do
      mov = MovimentoEstoque.new(quantidade: 5, valor: nil)
      expect(mov.valor_total).to be_nil
    end

    it "returns quantidade * valor when valor is present" do
      mov = MovimentoEstoque.new(quantidade: 5, valor: 10.5)
      expect(mov.valor_total).to eq(52.5)
    end
  end
end
