require "rails_helper"

# Etapa 1.2 (3/3, parte 2): production reads ResolucaoDoItem — each ordered
# number goes to the DXF size that serves it in its part.
RSpec.describe ProducaoPedidoService do
  let(:pedido) { create(:pedido) }
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }

  def corte(peca, filename, pares)
    create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo, filename: filename).tap do |c|
      c.moldes << molde
      pares.each_with_index { |(a, b), i| create(:tamanho, arquivo: c, nome: "#{a}-#{b}", numeros: [ a.to_s, b.to_s ], position: i + 1) }
    end
  end

  let!(:corte_lateral) { corte(lateral, "LATERAL", [ [ 29, 30 ], [ 31, 32 ] ]) }
  let!(:corte_lingua) { corte(lingua, "LINGUA", [ [ 30, 31 ] ]) }

  # An item of an arte with a file for every DXF size of both parts.
  def item(grade)
    primeiro = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: corte_lateral.tamanhos.first)
    create(:arquivo, arte: primeiro.arte, molde: molde, client: molde.client, peca: lateral, tamanho: corte_lateral.tamanhos.second)
    create(:arquivo, arte: primeiro.arte, molde: molde, client: molde.client, peca: lingua, tamanho: corte_lingua.tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: primeiro).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(primeiro))
      grade.each { |numero, qtd| i.grades.create!(tamanho_nome: numero, quantidade: qtd) }
    end
  end

  def tabela
    described_class.call(pedido).map { |l| [ l.peca&.nome, l.corte&.filename, l.quantidades.to_h, l.downloads.transform_values { |ts| ts.map(&:nome) } ] }
  end

  it "lists each checked part per DXF, each number with the DXF size that serves it" do
    item("29" => 4, "30" => 6, "31" => 2)
    expect(tabela).to eq([
      [ "Lateral", "LATERAL", { "29" => 4, "30" => 6, "31" => 2 }, { "29" => [ "29-30" ], "30" => [ "29-30" ], "31" => [ "31-32" ] } ],
      # The Língua DXF (Ímpar 30-31) doesn't serve the 29: a line without DXF.
      [ "Língua", nil, { "29" => 4 }, { "29" => [] } ],
      [ "Língua", "LINGUA", { "30" => 6, "31" => 2 }, { "30" => [ "30-31" ], "31" => [ "30-31" ] } ]
    ])
  end

  it "sums the same part across items and leaves unchecked parts out" do
    item("30" => 1)
    item("30" => 2).item_pedido_pecas.where(peca: lingua).update_all(incluida: false)
    expect(tabela.map { |peca, _, q, _| [ peca, q ] }).to eq([ [ "Lateral", { "30" => 3 } ], [ "Língua", { "30" => 1 } ] ])
  end

  it "orders numeric sizes by value, the single-total column last" do
    expect(described_class.ordenar_tamanhos(%w[36 _total 4 P])).to eq(%w[4 36 P _total])
  end
end
