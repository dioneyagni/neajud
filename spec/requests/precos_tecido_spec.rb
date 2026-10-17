require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.7b (decided 17/10/2026): the tecido's prices — the dono's print
# per meter and minimum per item (Parâmetros), the client's agreed print,
# each item's edited prices beside the starting ones (Q4) — and an item below
# the minimum, approved by the team for its meters (Q2); the cliente final
# sees what he pays and the minimum (Q5).
RSpec.describe "The tecido's prices", type: :request do
  let(:client) { create(:client, name: "Malharia Sul") }
  let(:oxford) { criar_tecido.tap { |t| t.update!(preco_metro: 20) } }
  let(:cor) { criar_obra_de_tecido("cor_lisa", client: client, no_catalogo: false, materia_prima: oxford) }

  def pedido_com(metros)
    post adicionar_item_pedidos_path, params: { arquivo_uuid: cor.arquivos.first.uuid, metros: metros }, as: :json
    Pedido.find_by!(uuid: response.parsed_body["pedido_uuid"])
  end

  def entrar_como_cliente_final(cliente)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: funcao).user)
  end

  it "the dono sets the print price and the minimum, a client his agreed print" do
    patch parametros_path, params: { empresa: { preco_impressao_metro_tecido: "15,50", metragem_minima_tecido: "10" } }
    expect(Empresa.atual.attributes.values_at("preco_impressao_metro_tecido", "metragem_minima_tecido")).to eq([ 15.5, 10 ])
    patch precos_tecido_client_path(client), params: { preco_impressao_metro_tecido: "12" }
    expect([ client.reload.preco_impressao_metro_tecido, flash[:notice] ]).to eq([ 12, "Malharia Sul's tecido price saved." ])
    get client_path(client)
    expect(Nokogiri::HTML(response.body).at_css("#cliente-preco-impressao-tecido")["placeholder"]).to eq("15,50")
  end

  it "the team edits an item's prices on the draft; blank goes back to the starting one" do
    Empresa.atual.update!(preco_impressao_metro_tecido: 15)
    pedido = pedido_com("10")
    pedido.update!(dono_tecido: "empresa")
    item = pedido.itens_pedido.first
    patch tecido_preco_item_pedido_path(pedido), params: { item_uuid: item.uuid, preco_impressao_metro: "13", preco_tecido_metro: "18,5" }
    expect([ item.reload.preco_impressao_metro, item.preco_tecido_metro, flash[:notice] ]).to eq([ 13, 18.5, "#{cor.titulo}: prices updated." ])
    get resumo_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    expect(html.css(".pedido-tecido-preco-linha .pedido-valores-partida").map(&:text)).to eq([ "R$ 15,00", "R$ 20,00" ])
    expect([ html.at_css(".pedido-tecido-subtotal-item").text, html.at_css("[data-resumo='total']").text, html.at_css("#valores-tecido .pedido-valores-desconto").text ]).to eq([ "R$ 315,00", "R$ 315,00", "R$ 35,00" ])
    patch tecido_preco_item_pedido_path(pedido), params: { item_uuid: item.uuid, preco_impressao_metro: "" }
    expect(item.reload.preco_impressao_efetivo).to eq(15)
    patch tecido_preco_item_pedido_path(pedido), params: { item_uuid: item.uuid, preco_tecido_metro: "-1" }
    expect(flash[:alert]).to include("Preco tecido metro must be greater than or equal to 0")
  end

  it "an item below the minimum waits for approval, which holds for its meters, and confirming writes the prices" do
    Empresa.atual.update!(preco_impressao_metro_tecido: 15, metragem_minima_tecido: 10)
    pedido = pedido_com("4")
    item = pedido.itens_pedido.first
    post confirmar_pedido_path(pedido)
    expect(pedido.reload.status).to eq("rascunho")
    post tecido_aprovar_minimo_pedido_path(pedido), params: { item_uuid: item.uuid }
    expect([ item.reload.minimo_aprovado_por, item.minimo_aprovado_metros, flash[:notice] ]).to eq([ @usuario_logado, 4, "#{cor.titulo}: approved below the minimum." ])
    get resumo_pedido_path(pedido)
    expect(Nokogiri::HTML(response.body).at_css(".pedido-tecido-minimo--aprovado").text).to include("Abaixo do mínimo de 10 m · aprovado por #{@usuario_logado.nome}")
    post confirmar_pedido_path(pedido)
    expect([ pedido.reload.status, item.reload.preco_impressao_metro_partida, item.preco_impressao_metro ]).to eq([ "confirmado", 15, 15 ])
  end

  it "refuses approving an item at or above the minimum, and a confirmed pedido's prices" do
    Empresa.atual.update!(preco_impressao_metro_tecido: 15, metragem_minima_tecido: 3)
    pedido = pedido_com("4")
    item = pedido.itens_pedido.first
    post tecido_aprovar_minimo_pedido_path(pedido), params: { item_uuid: item.uuid }
    expect([ item.reload.minimo_aprovado_em, flash[:alert] ]).to eq([ nil, "#{cor.titulo} is not below the minimum (4.0 m)" ])
    post confirmar_pedido_path(pedido)
    patch tecido_preco_item_pedido_path(pedido), params: { item_uuid: item.uuid, preco_impressao_metro: "1" }
    expect([ item.reload.preco_impressao_metro, flash[:alert] ]).to eq([ 15, "#{pedido.rotulo_lixeira} is confirmado; its prices change only while editable" ])
  end

  it "a cliente final sees what he pays and the minimum, never the starting price, nor edits or approves" do
    Empresa.atual.update!(preco_impressao_metro_tecido: 15, metragem_minima_tecido: 10)
    client.update!(visibilidade: { "valores" => true })
    pedido = pedido_com("4")
    pedido.itens_pedido.first.update!(preco_impressao_metro: 12)
    entrar_como_cliente_final(client)
    get resumo_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    expect([ html.at_css(".pedido-tecido-preco-metro").text, html.at_css(".pedido-tecido-subtotal-item").text ]).to eq([ "R$ 12,00/m", "R$ 48,00" ])
    expect(html.css(".pedido-valores-partida, .pedido-valores-desconto, .pedido-tecido-aprovar-minimo, .pedido-tecido-preco-linha")).to be_empty
    pendencia = html.at_css(".pedido-pendencia--abaixo_do_minimo")
    expect([ pendencia.text, pendencia.at_css(".pedido-pendencia-em-analise") ]).to match([ include("abaixo do mínimo: 4 m de 10 m"), nil ])
    patch tecido_preco_item_pedido_path(pedido), params: { item_uuid: pedido.itens_pedido.first.uuid, preco_impressao_metro: "1" }
    post tecido_aprovar_minimo_pedido_path(pedido), params: { item_uuid: pedido.itens_pedido.first.uuid }
    expect(response).to have_http_status(:forbidden)
    expect(pedido.itens_pedido.first.reload.attributes.values_at("preco_impressao_metro", "minimo_aprovado_em")).to eq([ 12, nil ])
  end
end
