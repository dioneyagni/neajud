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
    described_class.call(pedido).map { |l| [ l.peca&.nome, l.tamanho&.nome, l.quantidades.to_h, l.pecas ] }
  end

  it "lists each checked part per DXF size, with the numbers it serves and the pieces (2 per pair)" do
    item("29" => 4, "30" => 6, "31" => 2)
    expect(tabela).to eq([
      [ "Lateral", "29-30", { "29" => 4, "30" => 6 }, 20 ],
      [ "Lateral", "31-32", { "31" => 2 }, 4 ],
      [ "Língua", "30-31", { "30" => 6, "31" => 2 }, 16 ],
      # The Língua DXF (Ímpar 30-31) doesn't serve the 29: a line without size.
      [ "Língua", nil, { "29" => 4 }, 8 ]
    ])
  end

  it "sums the same part across items and leaves unchecked parts out" do
    item("30" => 1)
    item("30" => 2).item_pedido_pecas.where(peca: lingua).update_all(incluida: false)
    expect(tabela.map { |peca, tamanho, q, _| [ peca, tamanho, q ] }).to eq([ [ "Lateral", "29-30", { "30" => 3 } ], [ "Língua", "30-31", { "30" => 1 } ] ])
  end

  # Etapa 1.2 (3/3, parte 3b, decided 06/10/2026): pieces per pair and
  # mirrored come from the molde's part; "não corta" never reaches the table.
  it "counts pieces by the molde part, half right and half left when mirrored" do
    molde.molde_pecas.find_by(peca: lateral).update!(pecas_por_par: 4, espelhada: true)
    item("30" => 5)
    lateral_30 = described_class.call(pedido).first
    expect([ lateral_30.pares, lateral_30.pecas, lateral_30.por_lado ]).to eq([ 5, 20, 10 ])
    expect(described_class.call(pedido).second.por_lado).to be_nil
  end

  it "leaves out a part marked não corta on the molde" do
    molde.molde_pecas.find_by(peca: lingua).update!(needs_cut: false)
    item("30" => 1)
    expect(tabela.map(&:first)).to eq([ "Lateral" ])
  end
end
