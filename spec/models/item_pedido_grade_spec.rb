require "rails_helper"

RSpec.describe ItemPedidoGrade, type: :model do
  subject(:grade) { build(:item_pedido_grade) }

  describe "validations" do
    it { should validate_presence_of(:tamanho_nome) }
    it { should validate_presence_of(:quantidade) }
    it { should validate_numericality_of(:quantidade).is_greater_than_or_equal_to(0) }
  end

  describe "associations" do
    it { should belong_to(:item_pedido) }
  end

  describe "uniqueness" do
    it "validates uniqueness of tamanho_nome scoped to item_pedido" do
      item = create(:item_pedido)
      create(:item_pedido_grade, item_pedido: item, tamanho_nome: "Unico")
      dup = build(:item_pedido_grade, item_pedido: item, tamanho_nome: "Unico")
      expect(dup).not_to be_valid
      expect(dup.errors[:tamanho_nome]).to include("has already been taken")
    end
  end
end
