require "rails_helper"
require_relative "../support/tecidos"
require_relative "../support/construcoes"

# Dublagem 4/5 (decided 02/11/2026): a tecido item keeps its superfície and
# may name a construção on it — the empresa's or the pedido's client's.
RSpec.describe ConstrucaoDoItem do
  let(:client) { create(:client) }
  let(:pedido) { create(:pedido, client: client, tipo: "tecido") }
  let(:oxford) { material_de_dublagem("Oxford", largura: "1.60 m") }
  let(:lona) { material_de_dublagem("Lona", largura: "1.40 m") }
  let(:item) { create(:item_pedido, pedido: pedido, arquivo: criar_obra_de_tecido("corrida", client: client).arquivos.first, materia_prima: oxford, metros: 10) }

  # With a client, the Lona is his (a client's construção has a layer of his).
  def construcao(superficie = oxford, client: nil)
    montar_construcao([ superficie, "trama" ], [ lona, nil, { do_cliente: client.present? } ], client: client).tap(&:save!)
  end

  it "takes the empresa's construção on its superfície, and the client's" do
    expect(item.update(construcao: construcao)).to be(true)
    expect(item.update(construcao: construcao(client: client))).to be(true)
  end

  it "refuses another client's construção" do
    outra = construcao(client: create(:client))

    expect(item.update(construcao: outra)).to be(false)
    expect(item.errors[:construcao].first).to include("é de outro cliente")
  end

  it "refuses a construção whose superfície isn't the item's" do
    preto = construcao(material_de_dublagem("Oxford", cor: "Preto"))

    expect(item.update(construcao: preto)).to be(false)
    expect(item.errors[:construcao].first).to include("a superfície dela não é #{oxford.nome_completo}")
  end

  it "refuses a construção in the trash" do
    lixo = construcao.tap { |c| c.excluir!(changed_by: "spec") }

    expect(item.update(construcao: lixo)).to be(false)
    expect(item.errors[:construcao].first).to include("is in the trash")
  end

  it "lets go of the construção when the superfície changes, and says so" do
    dublado = construcao
    item.update!(construcao: dublado)
    item.update!(materia_prima: material_de_dublagem("Oxford", cor: "Preto"))

    expect([ item.construcao, item.construcao_solta ]).to eq([ nil, dublado ])
  end

  it "follows the dublado's width, the narrowest layer's, unless one is typed" do
    item.update!(construcao: construcao)
    expect(item.largura_efetiva_mm).to eq(1400)

    item.update!(largura_mm: 1500)
    expect(item.largura_efetiva_mm).to eq(1500)
  end

  it "says why the construção no longer serves once the pedido's client changed" do
    item.update!(construcao: construcao(client: client))
    pedido.update!(client: create(:client))

    expect(item.reload.motivo_da_construcao_que_nao_serve).to eq("é de outro cliente")
  end
end
