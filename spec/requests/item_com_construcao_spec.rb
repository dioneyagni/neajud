require "rails_helper"
require_relative "../support/tecidos"
require_relative "../support/construcoes"

# Dublagem 4/5 (decided 02/11/2026): a tecido item keeps its superfície and
# may be dubbed into a construção on it — the empresa's or the pedido's
# client's —, chosen by the team or by the cliente final on his draft; its
# dublado is charged at the construção's final price.
RSpec.describe "A tecido item with a construção", type: :request do
  let(:client) { create(:client, name: "Malharia Sul") }
  let(:oxford) { material_de_dublagem("Oxford", largura: "1.60 m", preco: 20) }
  let(:lona) { material_de_dublagem("Lona", largura: "1.40 m") }
  let(:pedido) { create(:pedido, client: client, tipo: "tecido") }
  let!(:item) { create(:item_pedido, pedido: pedido, arquivo: criar_obra_de_tecido("corrida", client: client).arquivos.first, materia_prima: oxford, metros: 10) }
  before { Empresa.atual.update!(preco_impressao_metro_tecido: 15) }

  def construcao(client: nil, preco_final: 46)
    montar_construcao([ oxford, "trama" ], [ lona, nil, { do_cliente: client.present? } ], client: client, preco_final: preco_final).tap(&:save!)
  end

  def entrar_como_cliente_final(cliente)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: funcao).user)
  end

  def pagina
    get resumo_pedido_path(pedido)
    Nokogiri::HTML(response.body)
  end

  it "the team dubs the item into a construção: its width, the dublado's price and when it dubs" do
    dublado = construcao
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, materia_prima_uuid: oxford.uuid, construcao_uuid: dublado.uuid, metros: "10" }

    expect([ item.reload.construcao, item.largura_efetiva_mm ]).to eq([ dublado, 1400 ])
    html = pagina
    expect(html.at_css(".pedido-tecido-construcao option[selected]").text).to eq("#{dublado.nome} · saldo 0 m")
    expect(html.at_css("[data-dublagem] .rede-chip").text).to eq("dubla antes da estampa")
    expect(html.at_css("[data-dublagem-producao]").text).to eq("o dublado sai do estoque (Dublagens)")
    expect(html.css(".pedido-tecido-preco-linha").map { |linha| linha["data-parte"] }).to eq([ "Impressão", "Material dublado" ])
    expect(html.at_css("#valores-tecido .pedido-valores-total").text).to eq("R$ 610,00")
  end

  it "lets go of the construção when the superfície changes, saying so" do
    item.update!(construcao: construcao)
    preto = material_de_dublagem("Oxford", cor: "Preto")
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, materia_prima_uuid: preto.uuid, construcao_uuid: item.construcao.uuid }

    expect(item.reload.construcao).to be_nil
    expect(flash[:notice]).to include("saiu do item: a superfície dela não é o tecido escolhido")
  end

  it "refuses another client's construção" do
    outra = construcao(client: create(:client))
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, construcao_uuid: outra.uuid }

    expect(flash[:alert]).to include("doesn't serve this item: é de outro cliente")
    expect(item.reload.construcao).to be_nil
  end

  # 4/5 decision 3: he picks among the empresa's and his own — another
  # client's never shows — and never sees how it is dubbed (the ligantes).
  it "a cliente final picks among the empresa's construções and his own" do
    da_empresa = construcao
    dele = construcao(client: client)
    construcao(client: create(:client, name: "Outro"))
    entrar_como_cliente_final(client)

    opcoes = pagina.css(".pedido-tecido-construcao option").map(&:text)
    expect(opcoes).to contain_exactly("— sem dublagem —", da_empresa.nome, "#{dele.nome} · saldo 0 m")
    expect(pagina.css("[data-dublagem]")).to be_empty
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, construcao_uuid: dele.uuid }
    expect(item.reload.construcao).to eq(dele)
  end

  it "a cliente final can't reach another client's construção by its uuid" do
    outra = construcao(client: create(:client))
    entrar_como_cliente_final(client)
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, construcao_uuid: outra.uuid }

    expect(response).to have_http_status(:not_found)
  end
end
