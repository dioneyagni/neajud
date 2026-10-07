require "rails_helper"

# Etapa 1.2 (3/3, parte 3c, decided 06/10/2026): what goes to the printer —
# per arte, one line per file, in pieces; "não corta" parts too.
RSpec.describe ImpressaoPedidoService do
  let(:pedido) { create(:pedido) }
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }

  def corte(peca, pares)
    create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo).tap do |c|
      c.moldes << molde
      pares.each_with_index { |(a, b), i| create(:tamanho, arquivo: c, nome: "#{a}-#{b}", numeros: [ a.to_s, b.to_s ], position: i + 1) }
    end
  end

  let!(:corte_lateral) { corte(lateral, [ [ 29, 30 ], [ 31, 32 ] ]) }
  let!(:corte_lingua) { corte(lingua, [ [ 30, 31 ] ]) }

  def arquivo(peca, tamanho, arte: nil, lado: nil, filename: nil)
    atributos = { molde: molde, client: molde.client, peca: peca, tamanho: tamanho, arte: arte, lado: lado, filename: filename }.compact
    create(:arquivo, **atributos)
  end

  def item_com(primeiro, grade)
    create(:item_pedido, pedido: pedido, arquivo: primeiro).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(primeiro))
      grade.each { |numero, qtd| i.grades.create!(tamanho_nome: numero, quantidade: qtd) }
    end
  end

  def linhas
    described_class.call(pedido).first.linhas.map { |l| [ l.peca.nome, l.tamanho&.nome, l.lado, l.arquivo&.filename, l.pendencia, l.pecas ] }
  end

  it "lists one line per file to print, in pieces, and what is missing" do
    a = arquivo(lateral, corte_lateral.tamanhos.first, filename: "lat-29_30")
    arquivo(lingua, corte_lingua.tamanhos.first, arte: a.arte, filename: "lin-30_31")
    item_com(a, "29" => 4, "30" => 6, "31" => 2)
    expect(linhas).to eq([
      [ "Lateral", "29-30", nil, "lat-29_30", nil, 20 ],
      [ "Lateral", "31-32", nil, nil, :sem_arquivo, 4 ],
      [ "Língua", "30-31", nil, "lin-30_31", nil, 16 ],
      [ "Língua", nil, nil, nil, :sem_corte, 8 ]
    ])
  end

  describe "a mirrored part" do
    before { molde.molde_pecas.find_by(peca: lateral).update!(espelhada: true) }

    it "prints each side's file for half the pieces, and lists a missing side" do
      a = arquivo(lateral, corte_lateral.tamanhos.first, lado: "direito", filename: "lat-dir")
      arquivo(lateral, corte_lateral.tamanhos.first, arte: a.arte, lado: "esquerdo", filename: "lat-esq")
      arquivo(lateral, corte_lateral.tamanhos.second, arte: a.arte, lado: "esquerdo", filename: "lat-31-esq")
      item_com(a, "30" => 5, "31" => 1)
      expect(linhas.select { |l| l.first == "Lateral" }).to eq([
        [ "Lateral", "29-30", "direito", "lat-dir", nil, 5 ],
        [ "Lateral", "29-30", "esquerdo", "lat-esq", nil, 5 ],
        [ "Lateral", "31-32", "direito", nil, :sem_lado, 1 ],
        [ "Lateral", "31-32", "esquerdo", "lat-31-esq", nil, 1 ]
      ])
    end

    it "prints a file without side for both sides, half mirrored" do
      item_com(arquivo(lateral, corte_lateral.tamanhos.first), "30" => 5)
      lateral_30 = described_class.call(pedido).first.linhas.first
      expect([ lateral_30.pecas, lateral_30.por_lado ]).to eq([ 10, 5 ])
    end
  end

  it "prints a part marked não corta too" do
    molde.molde_pecas.find_by(peca: lingua).update!(needs_cut: false)
    a = arquivo(lateral, corte_lateral.tamanhos.first)
    arquivo(lingua, corte_lingua.tamanhos.first, arte: a.arte)
    item_com(a, "30" => 1)
    expect(linhas.map(&:first)).to eq(%w[Lateral Língua])
  end

  it "leaves an unchecked part out" do
    a = arquivo(lateral, corte_lateral.tamanhos.first)
    item_com(a, "30" => 1).item_pedido_pecas.where(peca: lingua).update_all(incluida: false)
    expect(linhas.map(&:first)).to eq(%w[Lateral])
  end
end
