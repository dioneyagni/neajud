require "rails_helper"
require_relative "../support/tecidos"
require_relative "../support/construcoes"

# Etapa 2.7b (decided 17/10/2026): a tecido pedido charges per item its meters
# × the print per meter (edited > the client's agreed > the dono's) and, when
# the fabric is the empresa's, × the fabric per meter (edited > the
# material's); the starting prices stay beside to measure the discount.
RSpec.describe ValoresDoPedidoTecido do
  let(:empresa) { Empresa.atual || create(:empresa) }
  let(:client) { create(:client) }
  let(:pedido) { create(:pedido, client: client, tipo: "tecido") }
  let(:oxford) { criar_tecido.tap { |t| t.update!(preco_metro: 20) } }
  before { empresa.update!(preco_impressao_metro_tecido: 15) }

  def item(metros, **campos)
    create(:item_pedido, pedido: pedido, arquivo: criar_obra_de_tecido("corrida", client: client).arquivos.first, materia_prima: oxford, metros: metros, **campos)
  end

  it "charges the print only when the fabric is the client's" do
    item(10)
    valores = described_class.call(pedido)
    expect([ valores.itens.first.cobrancas.map(&:descricao), valores.total, valores.materiais ]).to eq([ [ "Impressão" ], 150, [] ])
  end

  it "charges the empresa's fabric at its material's price, and the client's agreed print over the dono's" do
    client.update!(preco_impressao_metro_tecido: 12)
    pedido.update!(dono_tecido: "empresa")
    um = item(2.5)
    valores = described_class.call(pedido)
    expect([ valores.do_item(um).preco_por_metro, valores.do_item(um).subtotal, valores.impressao.subtotal, valores.materiais.to_h.fetch("Tecido").subtotal ]).to eq([ 32, 80, 30, 50 ])
  end

  # Dublagem 4/5 (decision 4): the construção's final price already leaves
  # the client's layers out, so its dublado is charged whoever owns the fabric.
  it "charges an item with a construção its dublado at the final price, even with the client's fabric" do
    superficie = material_de_dublagem("Oxford", preco: 20)
    construcao = montar_construcao([ superficie, "trama" ], [ material_de_dublagem("Lona") ], preco_final: 46).tap(&:save!)
    dublado = item(10).tap { |um| um.update!(materia_prima: superficie, construcao: construcao) }
    valores = described_class.call(pedido)
    expect([ valores.do_item(dublado).cobrancas.map(&:descricao), valores.do_item(dublado).subtotal, valores.materiais.map(&:first) ])
      .to eq([ [ "Impressão", "Material dublado" ], 610, [ "Material dublado" ] ])
  end

  it "measures the discount of the edited prices and lists what has no price" do
    pedido.update!(dono_tecido: "empresa")
    item(10, preco_impressao_metro: 13)
    criar_tecido(grupo: "Linho").then { |linho| item(1).update!(materia_prima: linho) }
    valores = described_class.call(pedido)
    expect([ valores.desconto, valores.faltas.map(&:descricao) ]).to eq([ 20, [ "Tecido" ] ])
  end

  it "writes the starting and charged prices on confirming, and a confirmed pedido keeps them" do
    pedido.update!(dono_tecido: "empresa")
    um = item(3, preco_tecido_metro: 18)
    described_class.gravar!(pedido)
    pedido.update!(status: "confirmado")
    empresa.update!(preco_impressao_metro_tecido: 99)
    expect(um.reload.attributes.values_at("preco_impressao_metro_partida", "preco_impressao_metro", "preco_tecido_metro_partida", "preco_tecido_metro")).to eq([ 15, 15, 20, 18 ])
    expect(described_class.call(pedido.reload).total).to eq(99)
  end
end
