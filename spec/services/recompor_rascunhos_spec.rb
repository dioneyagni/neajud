require "rails_helper"

# 09/10/2026: a draft's item parts were a photo of the moment the arte was
# added; 42e40535 kept "Sem peça" (the file, its part unknown then) next to an
# empty Cabedal, and a Reforço the molde no longer had.
RSpec.describe RecomporRascunhos do
  let(:cabedal) { create(:peca, nome: "Cabedal") }
  let(:reforco) { create(:peca, nome: "Reforço") }
  let(:molde) { create(:molde, partes: [ cabedal, reforco ]) }
  let(:corte) do
    create(:arquivo, :corte, organized: true, peca: cabedal, client: molde.client, modelo: molde.modelo).tap { |c| c.moldes << molde }
  end
  let(:arte) { create(:arquivo, molde: molde, client: molde.client) }
  let(:pedido) { create(:pedido) }
  let!(:item) { create(:item_pedido, pedido: pedido, arquivo: arte).tap { |i| i.compor_pecas!(MoldeComposicaoService.call(arte)) } }

  def partes(i = item) = i.reload.item_pedido_pecas.map { |r| [ r.peca&.nome, r.arquivo, r.incluida ] }

  it "starts from the photo: the file's part unknown, an extra 'Sem peça' row" do
    expect(partes).to eq([ [ "Cabedal", nil, true ], [ "Reforço", nil, true ], [ nil, arte, true ] ])
  end

  it "follows the file's part once known, and the molde's parts, keeping an unchecked one and its row" do
    reforco_row = item.item_pedido_pecas.find_by!(peca: reforco).tap { |r| r.update!(incluida: false) }
    arte.update!(tamanho: create(:tamanho, arquivo: corte, nome: "29-30"))
    expect(partes).to eq([ [ "Cabedal", arte, true ], [ "Reforço", nil, false ] ])
    expect(item.item_pedido_pecas.find_by!(peca: reforco).uuid).to eq(reforco_row.uuid)

    molde.molde_pecas.find_by!(peca: reforco).destroy!
    expect(partes).to eq([ [ "Cabedal", arte, true ] ])
  end

  it "adds a part the molde gains, checked" do
    lingua = create(:peca, nome: "Língua")
    molde.molde_pecas.create!(peca: lingua)
    expect(partes.map(&:first)).to eq([ "Cabedal", "Reforço", "Língua", nil ])
  end

  it "leaves confirmed pedidos as they were confirmed" do
    pedido.update!(status: "confirmado")
    molde.molde_pecas.find_by!(peca: reforco).destroy!
    expect(partes.map(&:first)).to eq([ "Cabedal", "Reforço", nil ])
  end

  it "rebuilds every draft at once (the drafts made before it followed the molde)" do
    item.item_pedido_pecas.find_by!(peca: reforco).delete
    expect(described_class.todos).to eq(1)
    expect(partes.map(&:first)).to eq([ "Cabedal", "Reforço", nil ])
  end
end
