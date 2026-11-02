require "rails_helper"
require_relative "../support/construcoes"

RSpec.describe OpcoesDaConstrucao do
  let(:oxford) { material_de_dublagem("Oxford", cor: "Preto") }
  let(:opcoes) { described_class.new(MateriaPrima.all) }

  it "offers as superfície only the tecidos whose group goes on the face" do
    oxford
    material_de_dublagem("Lona")
    material_de_dublagem("Filme", tipo: "filme", micras: 35)

    expect(opcoes.superficies).to eq([ oxford ])
  end

  it "offers under a layer only the bases that dub with it, none before it has a material" do
    lona = material_de_dublagem("Lona")
    material_de_dublagem("Helanca")
    construcao = montar_construcao([ oxford, "trama" ], [ nil, nil ])

    expect(opcoes.bases_sob(construcao.superficie)).to contain_exactly(oxford, lona)
    expect(opcoes.bases_sob(montar_construcao([ nil, "trama" ]).superficie)).to be_empty
  end

  it "gives the network's ligação and the registered ligantes that serve it in a situação" do
    filme_25 = material_de_dublagem("Filme", tipo: "filme", micras: 25)
    filme_35 = material_de_dublagem("Filme", tipo: "filme", micras: 35)
    pu = material_de_dublagem("Filme PU", tipo: "filme", micras: 200)
    superficie = montar_construcao([ oxford, "trama" ]).superficie
    ligacao = opcoes.ligacao(superficie, oxford)

    expect(ligacao.dubla).to eq("antes")
    expect(opcoes.ligantes(ligacao, nil)).to contain_exactly(filme_25, filme_35)
    expect(opcoes.ligantes(ligacao, "vai_frequencia")).to eq([ filme_35 ])
    expect(opcoes.ligantes(ligacao, "tecido_molha")).to eq([ pu ])
  end
end
