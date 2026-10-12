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

  # Etapa 2.5c (decided 12/10/2026): a work without corte has no part, side
  # or piloto; a corrida or a cor lisa has no size either (sold by the meter).
  describe "the fields a work without corte doesn't keep" do
    let(:lateral) { create(:peca, nome: "Lateral") }

    it "clears the part and side read from a DTF file's name, keeping its size" do
      arquivo = create(:arquivo, category: "artes", peca: lateral, lado: "direito", tamanho_rotulo: "P", arte: Arte.novo_do_tipo("dtf"))
      expect(arquivo.reload.attributes.slice("peca_id", "lado", "tamanho_rotulo")).to eq("peca_id" => nil, "lado" => nil, "tamanho_rotulo" => "P")
    end

    it "clears the size of a corrida and a cor lisa" do
      corrida = create(:arquivo, category: "artes", tamanho_rotulo: "M", arte: Arte.novo_do_tipo("corrida"))
      cor = create(:arquivo, category: "artes", tamanho_rotulo: "M", arte: Arte.novo_do_tipo("cor_lisa"))
      expect([ corrida.reload.tamanho_rotulo, cor.reload.tamanho_rotulo ]).to eq([ nil, nil ])
    end

    it "keeps a calçado file's part, side and size" do
      arquivo = create(:arquivo, category: "artes", peca: lateral, lado: "direito", tamanho_rotulo: "29-30")
      expect(arquivo.reload.attributes.slice("peca_id", "lado", "tamanho_rotulo")).to eq("peca_id" => lateral.id, "lado" => "direito", "tamanho_rotulo" => "29-30")
    end

    it "clears the files when the arte changes kind, the piloto back to production" do
      piloto = create(:arquivo, category: "artes", peca: lateral, tamanho_rotulo: "29-30", papel: "piloto")
      outro = create(:arquivo, category: "artes", peca: lateral, tamanho_rotulo: "31-32", arte: piloto.arte)
      expect(piloto.arte.trocar_tipo!("corrida")).to be(true)
      expect([ piloto, outro ].map { |a| a.reload.attributes.slice("peca_id", "tamanho_rotulo", "papel") })
        .to all(eq("peca_id" => nil, "tamanho_rotulo" => nil, "papel" => "producao"))
    end

    it "refuses a piloto, naming the kind" do
      arquivo = create(:arquivo, category: "artes", arte: Arte.novo_do_tipo("dtf"))
      expect { arquivo.tornar_piloto! }.to raise_error(ActiveRecord::RecordInvalid, /Etiqueta DTF has no piloto/)
    end

    it "says which kinds use parts and sizes" do
      expect(TipoDaArte::TIPOS.map { |tipo| [ tipo, Arte.new(tipo: tipo).usa_pecas?, Arte.new(tipo: tipo).usa_tamanhos? ] })
        .to eq([ [ "calcado", true, true ], [ "dtf", false, true ], [ "corrida", false, false ], [ "cor_lisa", false, false ] ])
    end
  end
end
