require "rails_helper"

RSpec.describe Arte do
  let(:molde) { create(:molde) }

  it "lists its active files by part, sizes in the corte's order, unknown part last" do
    lateral = create(:peca, nome: "Lateral")
    corte = create(:arquivo, :corte, peca: lateral)
    grande = create(:tamanho, arquivo: corte, nome: "31-32", position: 2)
    pequeno = create(:tamanho, arquivo: corte, nome: "29-30", position: 1)
    primeiro = create(:arquivo, tamanho: grande)
    arte = primeiro.arte
    segundo = create(:arquivo, arte: arte, tamanho: pequeno)
    sem_parte = create(:arquivo, arte: arte, tamanho_rotulo: "P")
    create(:arquivo, arte: arte).excluir!(changed_by: "spec")

    expect(arte.arquivos_por_parte).to eq(lateral => [ segundo, primeiro ], nil => [ sem_parte ])
  end

  # Etapa 2.6a (decided 13/10/2026): a DTF has no corte to order its sizes
  # by; the file's measure does it, the smaller first, the label on a tie.
  it "orders a DTF's sizes by the file's measure, the label breaking ties, unmeasured last" do
    medido = lambda do |arte, rotulo, lado_px|
      create(:arquivo, arte: arte, tamanho_rotulo: rotulo).tap do |arquivo|
        versao = create(:arquivo_version, arquivo: arquivo, approved: true)
        ArquivoImageMetadata.create!(arquivo_version: versao, width_px: lado_px || 100, height_px: lado_px || 100, dpi: lado_px && 300)
        arquivo.update!(approved_version: versao)
      end
    end
    arte = Arte.novo_do_tipo("dtf").tap(&:save!)
    g = medido.call(arte, "G", 400)
    sem_dpi = medido.call(arte, "A", nil)
    p = medido.call(arte, "P", 200)
    m = medido.call(arte, "M", 300)
    empate = medido.call(arte, "M2", 300)
    expect(arte.arquivos_por_parte).to eq(nil => [ p, m, empate, g, sem_dpi ])
  end

  it "takes the dono's DTF spacing unless the arte has its own" do
    create(:empresa)
    arte = Arte.novo_do_tipo("dtf").tap(&:save!)
    expect(arte.espacamento_efetivo_mm).to eq(1.5)
    arte.update!(espacamento_mm: 2.5)
    expect(arte.espacamento_efetivo_mm).to eq(2.5)
    expect(arte.update(espacamento_mm: -1)).to be(false)
  end

  it "is represented by its first active file, titled by molde, referência and nome" do
    primeiro = create(:arquivo, molde: molde, referencia: Referencia.do_molde!(molde, "19"), nome: "Bluey", filename: "a")
    create(:arquivo, arte: primeiro.arte, filename: "b")
    expect([ primeiro.arte.principal, primeiro.arte.titulo ]).to eq([ primeiro, "#{molde.codigo} · 19 · Bluey" ])
  end

  it "is titled by its file's name before it has a molde" do
    expect(create(:arquivo, filename: "863-ARCOVERDE - P").arte.titulo).to eq("863-ARCOVERDE - P")
  end

  describe "#tamanhos_do_pedido (Etapa 1.2, 3/3)" do
    it "is the product's whole grade without an organized corte; the molde's stretch doesn't enter" do
      arte = create(:arquivo, molde: create(:molde, tamanho_inicial: "24", tamanho_final: "27")).arte
      expect(arte.tamanhos_do_pedido).to eq((18..46).map(&:to_s))
    end

    # Decided 05/10/2026: pre-listed with the corte's numbers.
    def corte_do_molde(molde, *tamanhos)
      corte = create(:arquivo, :corte, organized: true, client: molde.client, modelo: molde.modelo).tap { |c| c.moldes << molde }
      tamanhos.each_with_index { |(nome, numeros), i| create(:tamanho, arquivo: corte, nome: nome, numeros: numeros || [], position: i + 1) }
    end

    it "lists the numbers the molde's cortes serve" do
      molde = create(:molde)
      corte_do_molde(molde, [ "29-30", %w[29 30] ], [ "31-32", %w[31 32] ])
      expect(create(:arquivo, molde: molde).arte.tamanhos_do_pedido).to eq(%w[29 30 31 32])
    end

    it "deduces an old corte's numbers from its size names (24, 26 → 23 … 26)" do
      molde = create(:molde)
      corte_do_molde(molde, [ "24" ], [ "26" ])
      expect(create(:arquivo, molde: molde).arte.tamanhos_do_pedido).to eq(%w[23 24 25 26])
    end

    it "ignores the molde's stretch when there are cortes" do
      molde = create(:molde, tamanho_inicial: "24", tamanho_final: "26")
      corte_do_molde(molde, [ "23-24", %w[23 24] ], [ "25-26", %w[25 26] ], [ "27-28", %w[27 28] ])
      expect(create(:arquivo, molde: molde).arte.tamanhos_do_pedido).to eq(%w[23 24 25 26 27 28])
    end

    it "the whole product's grade may be asked, to add a number outside the cortes'" do
      molde = create(:molde)
      corte_do_molde(molde, [ "29-30", %w[29 30] ])
      arte = create(:arquivo, molde: molde).arte
      expect([ arte.tamanhos_do_pedido, arte.grade_completa_do_pedido ]).to eq([ %w[29 30], (18..46).map(&:to_s) ])
    end

    it "is empty without a molde (the pedido takes a single total)" do
      expect(create(:arquivo).arte.tamanhos_do_pedido).to eq([])
    end
  end
end
