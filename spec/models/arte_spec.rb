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

  it "is represented by its first active file, titled by molde, referência and nome" do
    primeiro = create(:arquivo, molde: molde, referencia: Referencia.do_molde!(molde, "19"), nome: "Bluey", filename: "a")
    create(:arquivo, arte: primeiro.arte, filename: "b")
    expect([ primeiro.arte.principal, primeiro.arte.titulo ]).to eq([ primeiro, "#{molde.codigo} · 19 · Bluey" ])
  end

  it "is titled by its file's name before it has a molde" do
    expect(create(:arquivo, filename: "863-ARCOVERDE - P").arte.titulo).to eq("863-ARCOVERDE - P")
  end

  describe "#tamanhos_do_pedido (Etapa 1.2, 3/3)" do
    it "is the molde's stretch of the grade, one by one" do
      arte = create(:arquivo, molde: create(:molde, tamanho_inicial: "24", tamanho_final: "27")).arte
      expect(arte.tamanhos_do_pedido).to eq(%w[24 25 26 27])
    end

    it "without a stretch, the numbers the molde's cortes serve; with old cortes, their size names" do
      molde = create(:molde)
      corte = create(:arquivo, :corte, organized: true, client: molde.client, modelo: molde.modelo).tap { |c| c.moldes << molde }
      create(:tamanho, arquivo: corte, nome: "31-32", numeros: %w[31 32], position: 2)
      create(:tamanho, arquivo: corte, nome: "29-30", numeros: %w[29 30], position: 1)
      arte = create(:arquivo, molde: molde).arte
      expect(arte.tamanhos_do_pedido).to eq(%w[29 30 31 32])
      Tamanho.update_all(numeros: [])
      expect(arte.tamanhos_do_pedido).to eq(%w[29-30 31-32])
    end

    it "the whole product's grade may be asked, to add a number outside the stretch" do
      arte = create(:arquivo, molde: create(:molde, tamanho_inicial: "24", tamanho_final: "27")).arte
      expect(arte.grade_completa_do_pedido).to eq((18..46).map(&:to_s))
    end

    it "is empty without a molde (the pedido takes a single total)" do
      expect(create(:arquivo).arte.tamanhos_do_pedido).to eq([])
    end
  end
end
