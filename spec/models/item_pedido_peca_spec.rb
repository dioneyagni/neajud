require "rails_helper"

RSpec.describe ItemPedidoPeca, type: :model do
  describe "#estado" do
    it "is :pendente when there is no arte, regardless of incluida" do
      expect(build(:item_pedido_peca, arquivo: nil, incluida: true).estado).to eq(:pendente)
      expect(build(:item_pedido_peca, arquivo: nil, incluida: false).estado).to eq(:pendente)
    end

    it "is :incluida when it has an arte and is checked" do
      expect(build(:item_pedido_peca, incluida: true).estado).to eq(:incluida)
    end

    it "is :excluida when it has an arte and was unchecked" do
      expect(build(:item_pedido_peca, incluida: false).estado).to eq(:excluida)
    end
  end

  describe "scopes" do
    let(:item) { create(:item_pedido) }
    let!(:incluida) { create(:item_pedido_peca, item_pedido: item, incluida: true) }
    let!(:excluida) { create(:item_pedido_peca, item_pedido: item, incluida: false) }
    let!(:pendente) { create(:item_pedido_peca, item_pedido: item, arquivo: nil) }

    it ".para_producao keeps only checked pieces that have an arte" do
      expect(described_class.para_producao).to contain_exactly(incluida)
    end

    it ".pendentes keeps only pieces without arte" do
      expect(described_class.pendentes).to contain_exactly(pendente)
    end
  end

  it "allows a peça only once per item" do
    existing = create(:item_pedido_peca)
    duplicate = build(:item_pedido_peca, item_pedido: existing.item_pedido, peca: existing.peca)
    expect(duplicate).not_to be_valid
  end

  it "allows several unknown-peça rows on the same item" do
    item = create(:item_pedido)
    create(:item_pedido_peca, item_pedido: item, peca: nil)
    expect(build(:item_pedido_peca, item_pedido: item, peca: nil)).to be_valid
  end
end
