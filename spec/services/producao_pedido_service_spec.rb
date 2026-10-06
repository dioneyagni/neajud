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

  describe "per corte, with the DXF to download for each size" do
    let(:corte) { create(:arquivo, :corte, peca: lateral, filename: "24 AO 34") }
    let!(:t34) { create(:tamanho, arquivo: corte, nome: "34") }
    let!(:t35) { create(:tamanho, arquivo: corte, nome: "35") }

    def item_on(corte_tamanho, grade)
      item = create(:item_pedido, pedido: pedido)
      grade.each { |nome, qtd| item.grades.create!(tamanho_nome: nome, quantidade: qtd) }
      create(:item_pedido_peca, item_pedido: item, peca: lateral, arquivo: create(:arquivo, tamanho: corte_tamanho))
    end

    it "maps each size to the corte's tamanho of the same name" do
      item_on(t34, { "34" => 2, "35" => 1 })
      linha = described_class.call(pedido).sole
      expect([ linha.corte, linha.downloads["34"], linha.downloads["35"], linha.tamanhos_faltando ]).to eq([ corte, [ t34 ], [ t35 ], [] ])
    end

    it "reports sizes the corte doesn't have" do
      item_on(t34, { "36" => 1 })
      expect(described_class.call(pedido).sole.tamanhos_faltando).to eq([ "36" ])
    end

    it "uses the arte's own tamanho for the single-total column" do
      item_on(t35, { "_total" => 4 })
      expect(described_class.call(pedido).sole.downloads["_total"]).to eq([ t35 ])
    end

    it "splits the same peça into one line per corte, so quantities don't mix" do
      outro = create(:arquivo, :corte, peca: lateral, filename: "35 AO 43")
      item_on(t34, { "34" => 2 })
      item_on(create(:tamanho, arquivo: outro, nome: "34"), { "34" => 5 })
      expect(described_class.call(pedido).map { |l| [ l.corte.filename, l.quantidades.to_h ] })
        .to eq([ [ "24 AO 34", { "34" => 2 } ], [ "35 AO 43", { "34" => 5 } ] ])
    end
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

  # Etapa 1.2 (3/3): the grade is by number; production finds the corte's
  # size serving it.
  it "maps each ordered number to the corte's size that serves it" do
    peca = create(:peca)
    corte = create(:arquivo, :corte, organized: true, peca: peca)
    par = create(:tamanho, arquivo: corte, nome: "29-30", numeros: %w[29 30])
    arte = create(:arquivo, tamanho: par, client: create(:client))
    item = create(:item_pedido, arquivo: arte)
    item.compor_pecas!(MoldeComposicaoService.call(arte))
    item.grades.create!(tamanho_nome: "29", quantidade: 4)
    item.grades.create!(tamanho_nome: "30", quantidade: 6)

    linha = described_class.call(item.pedido).sole
    expect([ linha.quantidades, linha.downloads.transform_values(&:to_a), linha.tamanhos_faltando ]).to eq([ { "29" => 4, "30" => 6 }, { "29" => [ par ], "30" => [ par ] }, [] ])
  end
end
