require "rails_helper"

RSpec.describe ItemPedido, type: :model do
  subject(:item) { build(:item_pedido) }

  describe "validations" do
    it "validates uuid uniqueness" do
      item.save!
      dup = build(:item_pedido, uuid: item.uuid)
      expect(dup).not_to be_valid
      expect(dup.errors[:uuid]).to include(/already been taken/i)
    end
  end

  describe "associations" do
    it { should belong_to(:pedido) }
    it { should belong_to(:arquivo) }
    it { should belong_to(:materia_prima).optional }
    it { should have_many(:grades).dependent(:destroy) }
  end

  describe "callbacks" do
    it "generates uuid before create" do
      item.save!
      expect(item.uuid).to be_present
      expect(item.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "#to_param" do
    it "returns uuid" do
      item.save!
      expect(item.to_param).to eq(item.uuid)
    end
  end

  describe "#quantidade_total" do
    it "sums grade quantities" do
      item.save!
      create(:item_pedido_grade, item_pedido: item, quantidade: 4)
      create(:item_pedido_grade, item_pedido: item, tamanho_nome: "Tam X", quantidade: 1)
      expect(item.quantidade_total).to eq(5)
    end

    it "returns 0 when no grades" do
      item.save!
      expect(item.quantidade_total).to eq(0)
    end
  end
end
