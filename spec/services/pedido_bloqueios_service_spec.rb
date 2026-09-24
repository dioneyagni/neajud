require "rails_helper"

RSpec.describe PedidoBloqueiosService do
  let(:pedido) { create(:pedido) }
  let(:lateral) { create(:peca, nome: "Lateral") }

  # An arte printed on a piece that has a corte (a tamanho of an organized corte).
  def arte_com_corte(filename: "com-corte")
    create(:arquivo, filename: filename, tamanho: create(:tamanho, arquivo: create(:arquivo, :corte, peca: lateral)))
  end

  def item(quantidade: 1, filename: "tenis")
    create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, filename: filename)).tap do |i|
      i.grades.create!(tamanho_nome: "35", quantidade: quantidade) if quantidade.positive?
    end
  end

  def bloqueios
    described_class.call(pedido).map { |b| [ b.tipo, b.descricao ] }
  end

  it "is empty for items with quantity whose checked pieces all have corte" do
    create(:item_pedido_peca, item_pedido: item, peca: lateral, arquivo: arte_com_corte)
    expect(bloqueios).to be_empty
  end

  it "flags an item with total quantity 0 (regression: pedido d7b86d8a was confirmed like this)" do
    item(quantidade: 0, filename: "zerado")
    expect(bloqueios).to eq([ [ :zerado, "Item zerado com quantidade total 0" ] ])
  end

  it "flags a checked piece whose arte has no corte, naming the arte" do
    create(:item_pedido_peca, item_pedido: item, peca: lateral, arquivo: create(:arquivo, filename: "28-GATO ROSA"))
    expect(bloqueios).to eq([ [ :sem_corte, "Lateral sem arquivo de corte (arte 28-GATO ROSA)" ] ])
  end

  it "ignores unchecked pieces without corte (they don't go to production)" do
    create(:item_pedido_peca, item_pedido: item, peca: lateral, arquivo: create(:arquivo), incluida: false)
    expect(bloqueios).to be_empty
  end

  it "flags pieces without arte, before quantity and corte problems" do
    zerado = item(quantidade: 0, filename: "tenis")
    create(:item_pedido_peca, item_pedido: zerado, peca: create(:peca, nome: "Língua"), arquivo: nil, position: 1)
    create(:item_pedido_peca, item_pedido: zerado, peca: lateral, arquivo: create(:arquivo, filename: "sem-corte"), position: 0)
    expect(bloqueios.map(&:first)).to eq(%i[sem_arte zerado sem_corte])
    expect(bloqueios.first.last).to eq("Língua sem arte (item tenis)")
  end
end
