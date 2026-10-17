require "rails_helper"
require_relative "../support/etiquetas_dtf"

# Etapa 2.6b1: what keeps a DTF draft from being confirmed.
RSpec.describe PedidoBloqueiosDtf do
  let(:client) { create(:client) }

  it "names a size without file, without measure or wider than the film, and an item at 0" do
    etiqueta = criar_etiqueta_dtf(client: client, tamanhos: { "P" => [ 191, 201 ], "G" => [ 8000, 8000 ] })
    etiqueta.arquivos.find_by!(tamanho_rotulo: "P").update_column(:encaixe_dtf, nil)
    pedido = create(:pedido, client: client, tipo: "dtf")
    item = create(:item_pedido, pedido: pedido, arquivo: etiqueta.arquivos.first)
    { "P" => 2, "G" => 1, "M" => 4 }.each { |tamanho, quantidade| item.grades.create!(tamanho_nome: tamanho, quantidade: quantidade) }
    create(:item_pedido, pedido: pedido, arquivo: etiqueta.arquivos.first)
    expect(described_class.call(pedido).map { |b| [ b.tipo, b.descricao ] }).to eq([
      [ :zerado, "Item #{etiqueta.titulo} com quantidade total 0" ],
      [ :sem_medida, "#{etiqueta.titulo} P (2): sem medida (o arquivo não tem tamanho ou DPI)" ],
      [ :nao_cabe, "#{etiqueta.titulo} G (1): não cabe no filme nem girada" ],
      [ :tamanho_sem_arquivo, "#{etiqueta.titulo} M (4): sem arquivo ativo desse tamanho" ]
    ])
  end

  # 16/10/2026: it turns only when the team marks it — the pendência says which way.
  it "asks to mark or unmark the turn when a size fits only the other way, the factory's to settle" do
    etiqueta = criar_etiqueta_dtf(client: client, tamanhos: { "P" => [ 6800, 118 ] }) # 575,7 mm wide: fits only turned
    pedido = create(:pedido, client: client, tipo: "dtf")
    create(:item_pedido, pedido: pedido, arquivo: etiqueta.arquivos.first).grades.create!(tamanho_nome: "P", quantidade: 3)
    descricoes = -> { described_class.call(pedido.reload).select { |b| b.tipo.to_s.start_with?("nao_cabe") }.map { |b| [ b.tipo, b.descricao ] } }
    expect(descricoes.call).to eq([ [ :nao_cabe_em_pe, "#{etiqueta.titulo} P (3): não cabe em pé no filme: marque Girar 90° na etiqueta" ] ])
    expect(PedidoBloqueiosService::DA_FABRICA).to include(:nao_cabe_em_pe, :nao_cabe_girada)
    etiqueta.update!(girar_dtf: true)
    expect(descricoes.call).to be_empty
  end

  # D4: the catálogo's etiquetas belong to whoever orders them.
  it "takes a catálogo etiqueta of another client, never one outside it" do
    create(:empresa, preco_metro_dtf: 120)
    pedido = create(:pedido, client: client, tipo: "dtf")
    catalogo = criar_etiqueta_dtf(client: create(:client), no_catalogo: true)
    create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: catalogo.arquivos.first)
    expect(described_class.call(pedido)).to be_empty
    catalogo.update!(no_catalogo: false)
    expect(described_class.call(pedido).map(&:tipo)).to eq(%i[arte_de_outro_cliente])
  end
end
