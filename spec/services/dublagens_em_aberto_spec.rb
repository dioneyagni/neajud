require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5a (decided 03/11/2026): what the confirmed pedidos miss of each
# dublado, per construção and owner, less the ordens already generated.
RSpec.describe DublagensEmAberto do
  let(:oxford) { material_de_dublagem("Oxford", largura: "1.60 m") }
  let(:filme) { material_de_dublagem("Filme", tipo: "filme", micras: 35) }
  let(:construcao) { montar_construcao([ oxford, "trama" ], [ material_de_dublagem("Lona"), filme ], preco_final: 46).tap(&:save!) }

  def abertas = described_class.call(aguardando: AguardandoMaterial.call, geradas: OrdemDublagem.geradas)

  it "gathers what several pedidos miss, less the stock and the ordens generated" do
    primeiro = pedido_dublado_confirmado(construcao, metros: 10)
    segundo = pedido_dublado_confirmado(construcao, metros: 8)
    MovimentoEstoque.create!(materia_prima: construcao.materia_prima, da_empresa: true, tipo: "entrada", quantidade: 3)
    OrdemDublagem.create!(construcao: construcao, metros: 5)

    linha = abertas.sole
    expect([ linha.construcao, linha.client, linha.falta, linha.gerados, linha.metros ]).to eq([ construcao, nil, 15.0, 5.0, 10.0 ])
    expect(linha.pedido_ids).to eq([ primeiro.id, segundo.id ])
  end

  it "is gone once an ordem done brings the dublado in, and while the ordens cover it" do
    pedido_dublado_confirmado(construcao, metros: 10)
    ordem = OrdemDublagem.create!(construcao: construcao, metros: 10)
    expect(abertas).to be_empty

    ordem.marcar_feita!(metros: 10, user: nil)
    expect([ abertas, AguardandoMaterial.call.pedido_ids ]).to eq([ [], [] ])
  end
end
