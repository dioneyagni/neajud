require "rails_helper"
require_relative "../support/construcoes"

RSpec.describe RegrasDaConstrucao do
  let(:oxford) { material_de_dublagem("Oxford", cor: "Preto") }
  let(:lona) { material_de_dublagem("Lona") }
  let(:filme_25) { material_de_dublagem("Filme", tipo: "filme", micras: 25) }
  let(:filme_35) { material_de_dublagem("Filme", tipo: "filme", micras: 35) }

  def erros(construcao) = described_class.new(construcao).erros

  it "accepts a superfície over a base that dubs with it, joined by a ligante the network allows" do
    expect(erros(montar_construcao([ oxford, "trama" ], [ lona, filme_35 ]))).to be_empty
  end

  it "asks for 2 to Parâmetros' maximum of layers, each with a material" do
    expect(erros(montar_construcao([ oxford, "trama" ]))).to eq([ "a construção tem 1 camada(s); esperado de 2 a 8" ])
    expect(erros(montar_construcao([ oxford, "trama" ], [ nil, filme_35 ]))).to eq([ "DUB-A, embaixo: escolha o material" ])
  end

  it "refuses a layer that isn't a tecido, and the wrong role for its place" do
    telinha = material_de_dublagem("Telinha")

    expect(erros(montar_construcao([ lona, "trama" ], [ oxford, filme_35 ]))).to include("DUB-A, em cima: Lona Branco não é superfície (grupo Lona)")
    expect(erros(montar_construcao([ oxford, "trama" ], [ telinha, filme_35 ]))).to include("DUB-A, embaixo: Telinha Branco não é base (grupo Telinha)")
    expect(erros(montar_construcao([ oxford, "trama" ], [ filme_35, filme_35 ]))).to include(a_string_starting_with("DUB-A, embaixo: Filme 35 µm-Branco-1.40 m é Ligante (dublagem); uma camada é um tecido"))
  end

  it "refuses a pair the network doesn't have" do
    helanca = material_de_dublagem("Helanca")

    expect(erros(montar_construcao([ oxford, "trama" ], [ helanca, filme_35 ]))).to eq([ "DUB-A: Oxford e Helanca não dublam — a rede não tem essa ligação" ])
  end

  # Oxford–Lona asks for filme of 35 µm or more; "tecido molha" swaps it for filme PU.
  it "refuses a ligante the network doesn't allow in the situação, saying what it asks" do
    expect(erros(montar_construcao([ oxford, "trama" ], [ lona, filme_25 ]))).to eq([ "DUB-A: Filme 25 µm-Branco-1.40 m não liga Oxford e Lona; a rede pede Filme 35 µm ou mais" ])
    expect(erros(montar_construcao([ oxford, "trama" ], [ lona, filme_35 ], situacao: "tecido_molha")))
      .to eq([ "DUB-A: Filme 35 µm-Branco-1.40 m não liga Oxford e Lona na situação Tecido molha; a rede pede Filme PU" ])
  end

  # Decision 4: a ligação with no registered material that serves (the cola,
  # until 5/5) saves without one; otherwise one must be chosen.
  it "asks for the ligante only when a registered one serves" do
    espuma = material_de_dublagem("Espuma", densidade: "TC4")
    expect(erros(montar_construcao([ oxford, "trama" ], [ espuma, nil ]))).to be_empty

    filme_35
    expect(erros(montar_construcao([ oxford, "trama" ], [ lona, nil ]))).to eq([ "DUB-A: escolha o ligante entre Oxford e Lona (Filme 35 µm ou mais)" ])
  end

  # Decision 2: a client's layer needs the client, and a client a layer of his.
  it "matches the client's layers with the client" do
    fagner = create(:client, name: "Fagner")

    expect(erros(montar_construcao([ oxford, "trama", { do_cliente: true } ], [ lona, filme_35 ]))).to eq([ "DUB-A, em cima: a camada é do cliente; escolha o cliente" ])
    expect(erros(montar_construcao([ oxford, "trama" ], [ lona, filme_35 ], client: fagner)))
      .to eq([ "Fagner não tem camada nesta construção: marque a camada dele ou tire o cliente" ])
  end

  it "refuses the same construção twice, pointing at the trash when the twin is there" do
    primeira = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ])
    primeira.save!

    expect(erros(montar_construcao([ oxford, "trama" ], [ lona, filme_35 ]))).to eq([ "igual a \"#{primeira.nome}\", que já existe" ])
    expect(erros(montar_construcao([ oxford, "avesso" ], [ lona, filme_35 ]))).to be_empty
    primeira.excluir!(changed_by: "127.0.0.1")
    expect(erros(montar_construcao([ oxford, "trama" ], [ lona, filme_35 ])).first).to include("is in the trash")
  end

  # Dublagem 5b1a (Q2d): the limit is Parâmetros'.
  it "takes the most layers from Parâmetros" do
    (Empresa.atual || create(:empresa)).update!(maximo_de_camadas: 2)

    expect(erros(montar_construcao([ oxford, "trama" ], [ lona, filme_35 ], [ lona, filme_35 ])).first).to eq("a construção tem 3 camada(s); esperado de 2 a 2")
  end

  it "asks to close the chave, naming the pieces still apart" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ])
    construcao.definir_camadas([ { materia_prima: oxford, lado: "trama" }, { materia_prima: lona, ligante: filme_35, ordem_da_dublagem: nil } ])

    expect(erros(construcao)).to include("a chave não fechou: falta juntar Oxford Preto e Lona Branco")
  end

  it "refuses a pair dubbed before the estampa onto a letra already dubbed after it" do
    espuma = material_de_dublagem("Espuma", densidade: "TC4")
    eva = material_de_dublagem("EVA")
    LigacaoDublagem.create!(grupo_a: espuma.grupo_material, grupo_b: eva.grupo_material, dubla: "antes")
    material_de_dublagem("Filme", tipo: "filme", micras: 25)

    expect(erros(montar_construcao([ oxford, "trama" ], [ espuma, nil ], [ eva, nil ])))
      .to include("DUB-B: a rede dubla Espuma e EVA antes da estampa, mas DUB-A já é depois da Calandra")
  end
end
