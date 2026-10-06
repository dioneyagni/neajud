require "rails_helper"

# Etapa 1.2 (3/3, parte 2): each part × ordered number → the DXF size that
# serves it → the arte's file of that size, the piloto as a sample, or a
# pendência (decided 05/10/2026).
RSpec.describe ResolucaoDoItem do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }

  def corte(peca, *pares)
    create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo).tap do |c|
      c.moldes << molde
      pares.each_with_index { |(a, b), i| create(:tamanho, arquivo: c, nome: "#{a}-#{b}", numeros: [ a.to_s, b.to_s ], position: i + 1) }
    end
  end

  def arquivo(peca, tamanho, arte: nil, papel: "producao")
    create(:arquivo, molde: molde, client: molde.client, peca: peca, tamanho: tamanho, arte: arte, papel: papel)
  end

  def item_com(primeiro, grade)
    item = create(:item_pedido, arquivo: primeiro)
    item.compor_pecas!(MoldeComposicaoService.call(primeiro))
    grade.each { |numero, qtd| item.grades.create!(tamanho_nome: numero, quantidade: qtd) }
    item
  end

  def resumo(item)
    described_class.call(item).to_h do |parte|
      [ parte.peca&.nome, parte.numeros.map { |n| [ n.numero, n.tamanho&.nome, n.arquivo&.filename, n.origem, n.pendencia ] } ]
    end
  end

  it "finds each number's DXF size per part and the arte's file of that size" do
    lat = corte(lateral, [ 29, 30 ], [ 31, 32 ])
    lin = corte(lingua, [ 30, 31 ])
    a = arquivo(lateral, lat.tamanhos.first)
    a.update!(filename: "lat-29_30")
    b = arquivo(lingua, lin.tamanhos.first, arte: a.arte)
    b.update!(filename: "lin-30_31")

    expect(resumo(item_com(a, "30" => 4, "31" => 2))).to eq(
      "Lateral" => [ [ "30", "29-30", "lat-29_30", :producao, nil ], [ "31", "31-32", nil, nil, :sem_arquivo ] ],
      "Língua" => [ [ "30", "30-31", "lin-30_31", :producao, nil ], [ "31", "30-31", "lin-30_31", :producao, nil ] ]
    )
  end

  it "marks a number no organized DXF of the part serves" do
    lat = corte(lateral, [ 29, 30 ])
    a = arquivo(lateral, lat.tamanhos.first)
    expect(resumo(item_com(a, "35" => 1))["Lateral"]).to eq([ [ "35", nil, nil, nil, :sem_corte ] ])
  end

  it "uses the size read from the file name while it has no tamanho" do
    lat = corte(lateral, [ 29, 30 ])
    a = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho_rotulo: "29-30", filename: "pelo-nome")
    expect(resumo(item_com(a, "29" => 1))["Lateral"].first.values_at(2, 3)).to eq([ "pelo-nome", :producao ])
  end

  # Etapa 1.2 (3/3, parte 3a): the pedido page's matrix shows every column of
  # the grade, ordered or not.
  describe "#celula with colunas" do
    it "gives an ordered number resolved and another just its DXF size" do
      lat = corte(lateral, [ 29, 30 ], [ 31, 32 ])
      a = arquivo(lateral, lat.tamanhos.first)
      parte = described_class.call(item_com(a, "30" => 2), colunas: %w[28 30 32]).find { |p| p.peca == lateral }
      expect(%w[28 30 32].map { |n| c = parte.celula(n); [ c.quantidade, c.tamanho&.nome, c.origem ] }).to eq(
        [ [ 0, nil, nil ], [ 2, "29-30", :producao ], [ 0, "31-32", nil ] ]
      )
    end
  end

  describe "the piloto as a sample" do
    let(:lat) { corte(lateral, [ 29, 30 ], [ 31, 32 ]) }
    let!(:piloto) { arquivo(lateral, lat.tamanhos.first, papel: "piloto").tap { |p| p.update!(filename: "piloto") } }

    it "covers an arte asked only in the piloto's size, with no production file for it" do
      expect(resumo(item_com(piloto, "29" => 1, "30" => 1))["Lateral"].map { |n| n.values_at(2, 3) }).to eq([ [ "piloto", :piloto ] ] * 2)
    end

    it "isn't used once more sizes are asked: production only, the rest pending" do
      expect(resumo(item_com(piloto, "30" => 1, "31" => 1))["Lateral"].map(&:last)).to eq([ :sem_arquivo, :sem_arquivo ])
    end

    it "gives way to a production file of that size" do
      arquivo(lateral, lat.tamanhos.first, arte: piloto.arte).update!(filename: "producao")
      expect(resumo(item_com(piloto, "30" => 1))["Lateral"].first.values_at(2, 3)).to eq([ "producao", :producao ])
    end
  end

  it "keeps a part the arte has no file for, every number pending" do
    lat = corte(lateral, [ 29, 30 ])
    corte(lingua, [ 29, 30 ])
    a = arquivo(lateral, lat.tamanhos.first)
    expect(resumo(item_com(a, "30" => 1))["Língua"]).to eq([ [ "30", "29-30", nil, nil, :sem_arquivo ] ])
  end

  # An arte without molde has no grade by number: the single total uses the
  # size chosen on the file itself, as before Etapa 1.2.
  it "resolves the single total of an arte without molde through its file's own size" do
    lat = create(:arquivo, :corte, organized: true, peca: lateral)
    tamanho = create(:tamanho, arquivo: lat, nome: "34")
    sem_molde = create(:arquivo, tamanho: tamanho, filename: "sem-molde")
    item = create(:item_pedido, arquivo: sem_molde)
    item.compor_pecas!(MoldeComposicaoService.call(sem_molde))
    item.grades.create!(tamanho_nome: "_total", quantidade: 3)
    expect(resumo(item)).to eq("Lateral" => [ [ "_total", "34", "sem-molde", :producao, nil ] ])
  end
end
