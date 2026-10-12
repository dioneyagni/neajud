require "rails_helper"

# Etapa 2.5a (decided 12/10/2026): the kind of work, its number and the coleção geral.
RSpec.describe TipoDaArte do
  it "numbers a DTF and a corrida in their own sequences, and leaves calçado without one" do
    dtf = Arte.novo_do_tipo("dtf").tap(&:save!)
    outra = Arte.novo_do_tipo("dtf").tap(&:save!)
    corrida = Arte.novo_do_tipo("corrida").tap(&:save!)
    expect([ dtf.codigo, outra.codigo, corrida.codigo, Arte.create!.codigo ]).to eq([ "DTF-1", "DTF-2", "CR-1", nil ])
  end

  it "gives a new number when the kind changes, never the old one back" do
    arte = Arte.novo_do_tipo("dtf").tap(&:save!)
    arte.trocar_tipo!("corrida")
    arte.trocar_tipo!("dtf")
    expect(arte.codigo).to eq("DTF-2")
  end

  # The cor lisa's number comes with its color family (2.5b).
  it "puts a cor lisa in the catálogo, without a number yet" do
    arte = Arte.novo_do_tipo("cor_lisa").tap(&:save!)
    expect([ arte.no_catalogo, arte.codigo, arte.rotulo_do_tipo ]).to eq([ true, nil, "Cor lisa" ])
  end

  it "keeps a calçado arte out of the catálogo" do
    arte = Arte.new(no_catalogo: true)
    expect(arte).not_to be_valid
    expect(arte.errors[:no_catalogo].first).to include("only a work without corte")
  end

  it "refuses an unknown kind, naming the expected ones" do
    arte = Arte.new(tipo: "bordado")
    expect(arte).not_to be_valid
    expect(arte.errors[:tipo].first).to include("bordado is not a kind of arte; expected one of calcado, dtf, corrida, cor_lisa")
  end

  it "refuses to change the kind of an arte a pedido uses, or one with a molde" do
    arquivo = create(:arquivo, category: "artes")
    create(:item_pedido, arquivo: arquivo)
    expect(arquivo.arte.trocar_tipo!("dtf")).to be(false)
    expect(arquivo.arte.errors[:tipo].first).to include("is in a pedido")
    com_molde = create(:arquivo, category: "artes", molde: create(:molde))
    expect(com_molde.arte.trocar_tipo!("dtf")).to be(false)
    expect(com_molde.arte.errors[:tipo].first).to include("unlink it first")
  end

  it "names a work without corte by its number: DTF-1_Arcoverde_P" do
    arquivo = create(:arquivo, category: "artes", filename: "863-ARCOVERDE", nome: "Arcoverde", tamanho_rotulo: "P", arte: Arte.novo_do_tipo("dtf"))
    expect(arquivo.nome_completo).to eq("DTF-1_Arcoverde_P")
    expect(arquivo.arte.titulo).to start_with("DTF-1")
  end

  it "takes no molde on a work without corte" do
    arquivo = create(:arquivo, category: "artes", arte: Arte.novo_do_tipo("dtf"))
    arquivo.molde = create(:molde)
    expect(arquivo).not_to be_valid
    expect(arquivo.errors[:molde].first).to include("Etiqueta DTF is a work without corte")
  end
end
