require "rails_helper"

RSpec.describe PedidoBloqueiosService do
  let(:pedido) { create(:pedido) }
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:molde) { create(:molde, partes: [ lateral ]) }
  # The molde's Lateral DXF, organized as Par: 29-30 (29, 30) and 31-32.
  let(:corte) do
    create(:arquivo, :corte, organized: true, peca: lateral, client: molde.client, modelo: molde.modelo, filename: "LATERAL").tap do |c|
      c.moldes << molde
      create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1)
      create(:tamanho, arquivo: c, nome: "31-32", numeros: %w[31 32], position: 2)
    end
  end

  # An item of an arte with a Lateral production file in 29-30.
  def item(grade: { "30" => 1 }, filename: "tenis", client: molde.client)
    arte = create(:arquivo, filename: filename, client: client, molde: molde, peca: lateral, tamanho: corte.tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: arte).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(arte))
      grade.each { |numero, qtd| i.grades.create!(tamanho_nome: numero, quantidade: qtd) }
    end
  end

  def bloqueios
    described_class.call(pedido).map { |b| [ b.tipo, b.descricao ] }
  end

  it "is empty when every ordered number of a checked part has its file" do
    item(grade: { "29" => 2, "30" => 1 })
    expect(bloqueios).to be_empty
  end

  it "flags an item with total quantity 0 (regression: pedido d7b86d8a was confirmed like this)" do
    item(grade: {}, filename: "zerado")
    expect(bloqueios).to eq([ [ :zerado, "Item #{molde.codigo} com quantidade total 0" ] ])
  end

  # Etapa 1.2 (3/3, parte 2): the pendências come from ResolucaoDoItem.
  it "flags a number the DXF serves but the arte has no file of, naming the size, with the DXF size to fill" do
    item(grade: { "31" => 1 })
    expect(bloqueios).to eq([ [ :sem_arquivo, "Lateral 31-32 (31×1) sem arquivo de produção na arte #{molde.codigo}" ] ])
    expect(described_class.call(pedido).first.tamanho).to eq(corte.tamanhos.second)
  end

  # Etapa 1.2 (3/3, parte 3a): one file settles every number of its size, so
  # the page shows one pendência (one "Enviar arquivo") per part × DXF size.
  it "groups the numbers of one DXF size into one pendência" do
    item(grade: { "31" => 1, "32" => 3 })
    expect(bloqueios).to eq([ [ :sem_arquivo, "Lateral 31-32 (31×1, 32×3) sem arquivo de produção na arte #{molde.codigo}" ] ])
  end

  it "flags the numbers no organized DXF of the part serves" do
    item(grade: { "35" => 1, "36" => 2 })
    expect(bloqueios).to eq([ [ :sem_corte, "Lateral 35×1, 36×2: nenhum corte organizado atende (arte #{molde.codigo})" ] ])
  end

  it "ignores an unchecked part (it doesn't go to production)" do
    item(grade: { "31" => 1 }).item_pedido_pecas.update_all(incluida: false)
    expect(bloqueios).to be_empty
  end

  # Regression (01/10/2026, ed6a2aba): confirming splits by the artes'
  # clients, so an arte without one would make a pedido without client.
  it "flags an item's arte without client" do
    create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, filename: "sem-cliente", client: nil)).grades.create!(tamanho_nome: "_total", quantidade: 1)
    expect(bloqueios).to include([ :arte_sem_cliente, "Arte sem-cliente sem cliente" ])
  end

  # Etapa 0.4: the item's file in the trash blocks; a trashed DXF stops
  # serving its numbers (pendência), it is never read.
  it "blocks the item's file in the trash, and a trashed DXF leaves its numbers pending" do
    arte = item.arquivo
    corte.excluir!(changed_by: "10.0.0.1")
    arte.excluir!(changed_by: "10.0.0.1")
    expect(bloqueios.map(&:first)).to eq(%i[arquivo_excluido sem_corte])
  end
end
