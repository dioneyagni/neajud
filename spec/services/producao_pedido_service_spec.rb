require "rails_helper"

RSpec.describe ProducaoPedidoService do
  let(:pedido) { create(:pedido) }
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }

  # An item with the given grade and pieces: { peca => :incluida/:excluida/:pendente }.
  def item_with(grade:, pecas:)
    item = create(:item_pedido, pedido: pedido)
    grade.each { |tamanho, qtd| item.grades.create!(tamanho_nome: tamanho, quantidade: qtd) }
    pecas.each_with_index do |(peca, estado), position|
      arquivo = estado == :pendente ? nil : create(:arquivo, peca: peca)
      create(:item_pedido_peca, item_pedido: item, peca: peca, arquivo: arquivo, incluida: estado != :excluida, position: position)
    end
    item
  end

  def table(linhas)
    linhas.map { |l| [ l.peca&.nome, l.quantidades.to_h, l.total ] }
  end

  it "lists each checked peça with the item's quantity per tamanho" do
    item_with(grade: { "35" => 10, "36" => 4 }, pecas: { lateral => :incluida, lingua => :incluida })
    expect(table(described_class.call(pedido)))
      .to eq([ [ "Lateral", { "35" => 10, "36" => 4 }, 14 ], [ "Língua", { "35" => 10, "36" => 4 }, 14 ] ])
  end

  it "leaves unchecked and pending pieces out" do
    item_with(grade: { "35" => 10 }, pecas: { lateral => :incluida, lingua => :excluida, create(:peca, nome: "Calcanhar") => :pendente })
    expect(described_class.call(pedido).map { |l| l.peca.nome }).to eq([ "Lateral" ])
  end

  it "sums the same peça across items" do
    item_with(grade: { "35" => 10 }, pecas: { lateral => :incluida })
    item_with(grade: { "35" => 2, "37" => 1 }, pecas: { lateral => :incluida, lingua => :excluida })
    expect(table(described_class.call(pedido))).to eq([ [ "Lateral", { "35" => 12, "37" => 1 }, 13 ] ])
  end

  it "keeps items without tamanhos under the single-total key" do
    item_with(grade: { "_total" => 7 }, pecas: { lateral => :incluida })
    expect(described_class.call(pedido).first.quantidades).to eq("_total" => 7)
  end

  it "links each peça to the corte of its arte" do
    corte = create(:arquivo, :corte, peca: lateral)
    item = create(:item_pedido, pedido: pedido)
    arte = create(:arquivo, tamanho: create(:tamanho, arquivo: corte))
    create(:item_pedido_peca, item_pedido: item, peca: lateral, arquivo: arte)
    expect(described_class.call(pedido).first.cortes).to eq([ corte ])
  end

  it "puts pieces without peça last" do
    item = create(:item_pedido, pedido: pedido)
    create(:item_pedido_peca, item_pedido: item, peca: nil, position: 0)
    create(:item_pedido_peca, item_pedido: item, peca: lateral, position: 1)
    expect(described_class.call(pedido).map { |l| l.peca&.nome }).to eq([ "Lateral", nil ])
  end

  it "ignores other pedidos" do
    item_with(grade: { "35" => 1 }, pecas: { lateral => :incluida })
    other = create(:item_pedido)
    create(:item_pedido_peca, item_pedido: other, peca: lingua)
    expect(described_class.call(pedido).map { |l| l.peca.nome }).to eq([ "Lateral" ])
  end

  describe ".ordenar_tamanhos" do
    it "orders numeric sizes by value, then names, then the single total" do
      expect(described_class.ordenar_tamanhos(%w[_total G 10 9 36 P 9])).to eq(%w[9 10 36 G P _total])
    end
  end
end
