require "rails_helper"
require_relative "../support/construcoes"

RSpec.describe Construcao do
  let(:oxford) { material_de_dublagem("Oxford", cor: "Preto", largura: "1.60 m", preco: 20) }
  let(:lona) { material_de_dublagem("Lona", largura: "1.40 m", preco: 10) }
  let(:filme_35) { material_de_dublagem("Filme", tipo: "filme", micras: 35, preco: 3) }

  # Decisions 1 and 3: its own dublado, the superfície's group and color,
  # the narrowest width, priced at the final price.
  it "saves with a dublado material from its layers" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ], preco_final: 46)

    expect(construcao.save).to be(true), construcao.errors.full_messages.to_sentence
    dublado = construcao.materia_prima
    expect(dublado).to have_attributes(tipo: "dublado", grupo_material: oxford.grupo_material, cor_material: oxford.cor_material, largura: "1.40 m", preco_metro: 46)
    expect(construcao.nome).to eq("Oxford Preto / Lona Branco-1.40 m")
    expect(dublado.nome_completo).to eq(construcao.nome)
  end

  # The client stays out: every client reads the list of materials.
  it "names the avesso and the situação, never the client" do
    fagner = create(:client, name: "Fagner")
    pu = material_de_dublagem("Filme PU", tipo: "filme")
    construcao = montar_construcao([ oxford, "avesso", { do_cliente: true } ], [ lona, pu ], situacao: "tecido_molha", client: fagner)

    expect(construcao.save).to be(true), construcao.errors.full_messages.to_sentence
    expect(construcao.nome).to eq("Oxford Preto (avesso) / Lona Branco-1.40 m (Tecido molha)")
  end

  it "keeps the layers' rows when they are set again, and removes the ones past the list" do
    eva = material_de_dublagem("EVA", preco: 5)
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ])
    construcao.save!
    primeira = construcao.camadas.first

    construcao.definir_camadas([ { materia_prima: oxford, lado: "trama" } ])
    expect(construcao.save).to be(false)
    expect(construcao.errors.full_messages).to include(a_string_matching(/1 camada\(s\); esperado de 2 a 5/))

    construcao.reload.definir_camadas([ { materia_prima: oxford, lado: "trama" }, { materia_prima: eva, ligante: material_de_dublagem("Filme", tipo: "filme", micras: 25) } ])
    construcao.save!
    expect(construcao.camadas.reload.map(&:id).first).to eq(primeira.id)
    expect(construcao.nome).to eq("Oxford Preto / EVA Branco-1.40 m")
  end

  # Decision 5: once its dublado is used, only the final price changes.
  it "refuses changing the layers of a construção in use, never its final price" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ])
    construcao.save!
    MovimentoEstoque.create!(materia_prima: construcao.materia_prima, tipo: "entrada", quantidade: 10, da_empresa: true)

    expect(construcao.reload.update(preco_final: 50)).to be(true)
    expect(construcao.materia_prima.reload.preco_metro).to eq(50)
    construcao.situacao = "tecido_molha"
    expect(construcao.save).to be(false)
    expect(construcao.errors.full_messages.to_sentence).to include("já está em uso (estoque ou pedido): só o preço final muda")
  end

  it "refuses an unknown situação, naming the known ones" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ], situacao: "chove")

    expect(construcao.save).to be(false)
    expect(construcao.errors[:situacao].first).to eq("chove is not a situação; expected one of vai_frequencia, tecido_molha")
  end

  it "goes to the trash and back, keeping its dublado" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ])
    construcao.save!

    construcao.excluir!(changed_by: "127.0.0.1")
    expect(described_class.ativos).to be_empty
    expect(construcao.materia_prima.reload).to be_persisted
  end
end
