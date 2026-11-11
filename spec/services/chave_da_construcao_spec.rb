require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5b1a (decided 10/11/2026): the canvas's chave, with this network's
# groups — DUB-A Oxford/Lona and DUB-B Espuma/Helanca in the 1st dublagem,
# DUB-C = DUB-B with EVA in the 2nd, DUB-D = DUB-A with DUB-C in the 3rd.
RSpec.describe ChaveDaConstrucao do
  let(:oxford) { material_de_dublagem("Oxford", cor: "Preto") }
  let(:lona) { material_de_dublagem("Lona") }
  let(:espuma) { material_de_dublagem("Espuma", densidade: "TC4") }
  let(:helanca) { material_de_dublagem("Helanca") }
  let(:eva) { material_de_dublagem("EVA") }

  before do
    importar_rede_de_dublagens
    grupos = GrupoMaterial.where(nome: %w[Lona Espuma Helanca EVA]).index_by(&:nome)
    LigacaoDublagem.create!(grupo_a: grupos["Lona"], grupo_b: grupos["Espuma"], dubla: "depois")
    LigacaoDublagem.create!(grupo_a: grupos["Helanca"], grupo_b: grupos["EVA"], dubla: "depois")
  end

  # ordens: the dublagem of each base, top to bottom (nil = not joined).
  def construcao_com(materiais, ordens)
    construcao = Construcao.new
    construcao.definir_camadas([ { materia_prima: materiais.first, lado: "trama" } ] +
                               materiais.drop(1).zip(ordens).map { |material, ordem| { materia_prima: material, ordem_da_dublagem: ordem } })
    construcao
  end

  let(:chave) { described_class.new(construcao_com([ oxford, lona, espuma, helanca, eva ], [ 1, 3, 1, 2 ])) }

  def lados(dublagem) = dublagem.lados.map(&:nome)

  it "reads the dublagens by column, top to bottom, each one column after the latest letra it uses" do
    expect(chave.dublagens.map { |dublagem| [ dublagem.letra, dublagem.coluna, lados(dublagem) ] }).to eq([
      [ "DUB-A", 1, [ "Oxford Preto", "Lona Branco" ] ], [ "DUB-B", 1, [ "Espuma TC4 Branco", "Helanca Branco" ] ],
      [ "DUB-C", 2, [ "DUB-B", "EVA Branco" ] ], [ "DUB-D", 3, [ "DUB-A", "DUB-C" ] ]
    ])
    expect(chave).to be_fechada
    expect(chave.final.letra).to eq("DUB-D")
    expect(chave.colunas).to eq(3)
  end

  it "says the columns a letra passes through before the one using it" do
    a, b, c, = chave.dublagens

    expect([ chave.segue(a), chave.segue(b), chave.segue(c) ]).to eq([ [ 2 ], [], [] ])
  end

  # Q5a: without the superfície it runs with the Impressão whatever the
  # network says; with it, after the Calandra once its pair (or the letra
  # with the superfície) dubs after the estampa.
  it "deduces each one's momento against the Calandra and where the estampa goes" do
    expect(chave.dublagens.map { |dublagem| [ dublagem.momento_da_rede, dublagem.momento_real ] })
      .to eq([ %w[antes antes], %w[depois antes], %w[depois antes], %w[depois depois] ])
    expect(chave.dublagens.select(&:recebe_estampa?).map(&:letra)).to eq([ "DUB-A" ])
    expect(chave.dublagens.select(&:conflito?)).to be_empty
  end

  it "flags a pair dubbed before the estampa onto a letra already dubbed after it" do
    LigacaoDublagem.create!(grupo_a: GrupoMaterial.find_by!(nome: "Espuma"), grupo_b: GrupoMaterial.find_by!(nome: "EVA"), dubla: "antes")
    conflito = described_class.new(construcao_com([ oxford, espuma, eva ], [ 1, 2 ]))

    expect(conflito.dublagens.map { |dublagem| [ dublagem.letra, dublagem.momento_real, dublagem.conflito? ] }).to eq([ [ "DUB-A", "depois", false ], [ "DUB-B", "depois", true ] ])
  end

  # 11/11/2026 (Q1a/Q2a): a ligação allowing both — the card picks, "antes"
  # until it does; once the letra with the superfície is after, so is the
  # one joining it, with no conflict.
  it "lets a ligação allowing both follow the card's pick, or the letra it joins" do
    grupos = GrupoMaterial.where(nome: %w[Oxford Lona Espuma]).index_by(&:nome)
    LigacaoDublagem.do_par(grupos["Oxford"], grupos["Lona"]).sole.update!(dubla: "antes e depois")
    LigacaoDublagem.do_par(grupos["Lona"], grupos["Espuma"]).sole.update!(dubla: "antes e depois")
    construcao = construcao_com([ oxford, lona, espuma ], [ 1, 2 ])
    leitura = -> { described_class.new(construcao).dublagens.map { |dublagem| [ dublagem.letra, dublagem.momento_real, dublagem.escolhe_momento?, dublagem.momento_obrigado?, dublagem.conflito? ] } }

    expect(leitura.()).to eq([ [ "DUB-A", "antes", true, false, false ], [ "DUB-B", "antes", true, false, false ] ])
    construcao.camadas_em_ordem.second.dubla = "depois"
    expect(leitura.()).to eq([ [ "DUB-A", "depois", true, false, false ], [ "DUB-B", "depois", false, true, false ] ])
  end

  it "keeps the pieces not joined yet apart, and says where a layer is" do
    aberta = described_class.new(construcao_com([ oxford, lona, espuma, helanca ], [ 1, nil, 1 ]))

    expect(aberta).not_to be_fechada
    expect(aberta.pecas.map(&:nome)).to eq(%w[DUB-A DUB-B])
    expect(aberta.lugar(aberta.pecas.last.baixo.camada)).to eq("DUB-B, embaixo")
  end

  it "dubs a stack made before the chave top to bottom, one layer per dublagem" do
    pilha = described_class.new(montar_construcao([ oxford, "trama" ], [ lona, nil ], [ espuma, nil ]))

    expect(pilha.dublagens.map { |dublagem| [ dublagem.letra, lados(dublagem) ] }).to eq([ [ "DUB-A", [ "Oxford Preto", "Lona Branco" ] ], [ "DUB-B", [ "DUB-A", "Espuma TC4 Branco" ] ] ])
  end

  it "names the 27th letra DUB-AA" do
    expect([ described_class.letra(0), described_class.letra(25), described_class.letra(26) ]).to eq(%w[DUB-A DUB-Z DUB-AA])
  end
end
