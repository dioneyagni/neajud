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

  # D4: the catálogo's etiquetas belong to whoever orders them.
  it "takes a catálogo etiqueta of another client, never one outside it" do
    pedido = create(:pedido, client: client, tipo: "dtf")
    catalogo = criar_etiqueta_dtf(client: create(:client), no_catalogo: true)
    create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: catalogo.arquivos.first)
    expect(described_class.call(pedido)).to be_empty
    catalogo.update!(no_catalogo: false)
    expect(described_class.call(pedido).map(&:tipo)).to eq(%i[etiqueta_de_outro_cliente])
  end
end
