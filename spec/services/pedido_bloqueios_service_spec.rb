require "rails_helper"

RSpec.describe PedidoBloqueiosService do
  let(:pedido) { create(:pedido) }
  let(:lateral) { create(:peca, nome: "Lateral") }

  # An arte printed on a piece whose corte has a tamanho named like the grade ("35").
  def arte_com_corte(filename: "com-corte")
    create(:arquivo, filename: filename, tamanho: create(:tamanho, nome: "35", arquivo: create(:arquivo, :corte, peca: lateral)))
  end

  def item(quantidade: 1, filename: "tenis", client: create(:client))
    create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, filename: filename, client: client)).tap do |i|
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

  it "flags a size the pedido asks for that the piece's corte doesn't have (no DXF to download)" do
    corte = create(:arquivo, :corte, peca: lateral, filename: "24 AO 34 - CABEDAL")
    arte = create(:arquivo, tamanho: create(:tamanho, nome: "34", arquivo: corte))
    pedido_item = item(quantidade: 0)
    pedido_item.grades.create!(tamanho_nome: "34", quantidade: 2)
    pedido_item.grades.create!(tamanho_nome: "35", quantidade: 1)
    create(:item_pedido_peca, item_pedido: pedido_item, peca: lateral, arquivo: arte)
    expect(bloqueios).to eq([ [ :tamanho_sem_corte, "Lateral 35: tamanho não existe no corte 24 AO 34 - CABEDAL" ] ])
  end

  # Regression (01/10/2026, ed6a2aba): confirming splits by the artes'
  # clients, so an arte without one would make a pedido without client.
  it "flags an item's arte without client" do
    item(filename: "sem-cliente", client: nil)
    expect(bloqueios).to eq([ [ :arte_sem_cliente, "Arte sem-cliente sem cliente" ] ])
  end

  describe "arquivos in the trash (Etapa 0.4)" do
    it "blocks when a checked piece's arte or corte, or the item's arte, is trashed" do
      arte = arte_com_corte(filename: "lateral-azul")
      pedido_item = item
      create(:item_pedido_peca, item_pedido: pedido_item, peca: lateral, arquivo: arte)
      [ arte, arte.corte, pedido_item.arquivo ].each { |a| a.excluir!(changed_by: "10.0.0.1") }

      expect(bloqueios.select { |tipo, _| tipo == :arquivo_excluido }.map(&:last))
        .to contain_exactly("tenis está na lixeira", "lateral-azul está na lixeira", "#{arte.corte.filename} está na lixeira")
    end

    it "ignores a trashed arte of an unchecked piece (it doesn't go to production)" do
      arte = arte_com_corte
      create(:item_pedido_peca, item_pedido: item, peca: lateral, arquivo: arte, incluida: false)
      arte.excluir!(changed_by: "10.0.0.1")
      expect(bloqueios).to be_empty
    end
  end
end
