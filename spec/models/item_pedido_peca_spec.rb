require "rails_helper"

RSpec.describe ItemPedidoPeca, type: :model do
  # Etapa 1.2 (3/3): what is missing is ResolucaoDoItem's; a part is only
  # checked or unchecked.
  describe "#estado" do
    it "is :incluida when checked and :excluida when unchecked" do
      expect([ build(:item_pedido_peca, incluida: true).estado, build(:item_pedido_peca, incluida: false).estado ]).to eq(%i[incluida excluida])
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
