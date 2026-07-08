require "rails_helper"

RSpec.describe Pedido, type: :model do
  subject(:pedido) { build(:pedido) }

  describe "validations" do
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[rascunho confirmado cancelado]) }

    it "validates uuid uniqueness" do
      pedido.save!
      dup = build(:pedido, uuid: pedido.uuid)
      expect(dup).not_to be_valid
      expect(dup.errors[:uuid]).to include(/already been taken/i)
    end
  end

  describe "associations" do
    it { should belong_to(:client).optional }
    it { should have_many(:itens_pedido).dependent(:destroy) }
  end

  describe "callbacks" do
    it "generates uuid before create" do
      pedido.save!
      expect(pedido.uuid).to be_present
      expect(pedido.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "#to_param" do
    it "returns uuid" do
      pedido.save!
      expect(pedido.to_param).to eq(pedido.uuid)
    end
  end

  describe "#total_itens" do
    it "sums grade quantities" do
      pedido.save!
      item = create(:item_pedido, pedido: pedido)
      create(:item_pedido_grade, item_pedido: item, quantidade: 3)
      create(:item_pedido_grade, item_pedido: item, tamanho_nome: "Tam X", quantidade: 2)
      expect(pedido.total_itens).to eq(5)
    end

    it "returns 0 when no grades exist" do
      pedido.save!
      create(:item_pedido, pedido: pedido)
      expect(pedido.total_itens).to eq(0)
    end
  end

  describe "scopes" do
    it ".rascunhos includes rascunho pedidos" do
      p = create(:pedido, status: "rascunho")
      expect(Pedido.rascunhos).to include(p)
    end

    it ".rascunhos excludes confirmado pedidos" do
      p = create(:pedido, status: "confirmado")
      expect(Pedido.rascunhos).not_to include(p)
    end

    it ".confirmados includes confirmado pedidos" do
      p = create(:pedido, status: "confirmado")
      expect(Pedido.confirmados).to include(p)
    end
  end
end
