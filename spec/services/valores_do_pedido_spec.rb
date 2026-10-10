require "rails_helper"

# Etapa 2.4 (decided 09/10/2026): price per pair (written at confirmation,
# else the molde's now), cost per pair (always now) and margin.
RSpec.describe ValoresDoPedido do
  let(:molde) { create(:molde) }
  let(:empresa) { Empresa.new(nome: "Neajud", custo_impressao_metro: 10, custo_corte_peca: 1) }
  let(:pedido) { create(:pedido) }
  let!(:item) do
    molde.faixas_de_preco.create!(tamanho_inicial: "18", tamanho_final: "30", preco_par: 12)
    arte = create(:arquivo, molde: molde, client: molde.client)
    create(:item_pedido, pedido: pedido, arquivo: arte).tap do |i|
      i.grades.create!(tamanho_nome: "30", quantidade: 10)
      i.grades.create!(tamanho_nome: "31", quantidade: 2)
    end
  end

  # One part (no file of the arte, cut): R$ 2 per pair, incompleto.
  before { item.item_pedido_pecas.create!(peca: create(:peca), position: 0) }

  it "multiplies each number's pairs by its price and cost; a number without price is left out of the value" do
    valores = described_class.call(pedido, empresa: empresa)
    linhas = valores.itens.sole.linhas
    expect(linhas.map { |l| [ l.numero, l.pares, l.preco_par, l.custo_par, l.margem_par ] }).to eq([ [ "30", 10, 12, 2, 10 ], [ "31", 2, nil, 2, nil ] ])
    expect([ valores.valor, valores.custo, valores.margem, valores.sem_preco? ]).to eq([ 120, 24, 96, true ])
  end

  it "reads the price written at confirmation, not the molde's price now" do
    item.grades.find_by!(tamanho_nome: "30").update!(preco_par: 9)
    molde.faixas_de_preco.sole.update!(preco_par: 15)
    expect(described_class.call(pedido, empresa: empresa).itens.sole.linhas.first.preco_par).to eq(9)
  end

  it "has no cost while the dono hasn't set the costs" do
    valores = described_class.call(pedido, empresa: Empresa.new(nome: "Neajud"))
    expect([ valores.itens.sole.linhas.first.custo_par, valores.custo ]).to eq([ nil, 0 ])
  end
end
