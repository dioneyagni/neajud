require "rails_helper"

# Etapa 2.4 (decided 09/10/2026): the cost of one pair, per number — the
# meters its files take at the printing cost, plus the pieces cut.
RSpec.describe CustoPorPar do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }
  let(:empresa) { Empresa.new(nome: "Neajud", largura_papel_mm: 1600, custo_impressao_metro: 10, custo_corte_peca: "0.5") }
  let(:cortes) do
    [ lateral, lingua ].to_h do |peca|
      corte = create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo).tap { |c| c.moldes << molde }
      [ peca, create(:tamanho, arquivo: corte, nome: "29-30", numeros: %w[29 30], position: 1) ]
    end
  end
  let!(:arte) { no_papel(create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: cortes[lateral])) }

  # 254 × 50,8 mm: 6 across the 1,60 m paper → 0,00847 m per piece.
  def no_papel(arquivo)
    version = create(:arquivo_version, arquivo: arquivo, approved: true)
    ArquivoImageMetadata.create!(arquivo_version: version, width_px: 3000, height_px: 600, dpi: 300)
    arquivo.tap { |a| a.update!(approved_version_id: version.id) }
  end

  def item(grade)
    create(:item_pedido, arquivo: arte).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(arte))
      grade.each { |numero, qtd| i.grades.create!(tamanho_nome: numero, quantidade: qtd) }
    end
  end

  def valores(custo) = [ custo.impressao.round(4), custo.corte, custo.total.round(4), custo.incompleto ]

  it "adds each part's printed meters at the cost per meter and the pieces cut at the cost per piece" do
    no_papel(create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: cortes[lingua]))
    custos = described_class.call(item("30" => 5), empresa: empresa)
    # Per pair: 2 laterals + 2 línguas × 0,00847 m × R$ 10; 4 pieces cut × R$ 0,50.
    expect(valores(custos["30"])).to eq([ 0.3388, 2, 2.3388, false ])
  end

  it "leaves out the cutting of a part that doesn't cut (it is still printed)" do
    no_papel(create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: cortes[lingua]))
    molde.molde_pecas.find_by(peca: lingua).update!(needs_cut: false)
    expect(valores(described_class.call(item("30" => 1), empresa: empresa)["30"])).to eq([ 0.3388, 1, 1.3388, false ])
  end

  it "is incompleto while a part has no file: it counts what is known, saying which part misses what" do
    custo = described_class.call(item("29" => 1), empresa: empresa)["29"]
    expect(valores(custo)).to eq([ 0.1694, 2, 2.1694, true ])
    expect(custo.faltas.map { |f| [ f.peca, f.motivo ] }).to eq([ [ lingua, :sem_arquivo ] ])
  end

  it "names a file without its size on the paper (no DPI yet)" do
    create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: cortes[lingua])
    expect(described_class.call(item("30" => 1), empresa: empresa)["30"].faltas.map(&:motivo)).to eq([ :sem_medida ])
  end

  it "prints half the pieces from each side's file of a mirrored part" do
    molde.molde_pecas.find_by(peca: lateral).update!(espelhada: true)
    molde.molde_pecas.find_by(peca: lingua).update!(needs_cut: false)
    arte.update!(lado: "direito")
    no_papel(create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lateral, tamanho: cortes[lateral], lado: "esquerdo"))
    no_papel(create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: cortes[lingua]))
    expect(valores(described_class.call(item("30" => 1), empresa: empresa)["30"])).to eq([ 0.3388, 1, 1.3388, false ])
  end

  it "gives the arte's cost for every number a pedido may ask, before any pedido" do
    custos = described_class.da_arte(arte, empresa: empresa)
    expect(custos.keys).to eq(%w[29 30])
    expect(ItemPedido.count).to eq(0)
  end
end
