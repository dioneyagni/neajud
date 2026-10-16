require "rails_helper"
require_relative "../support/etiquetas_dtf"

# Etapa 2.6b1 (decided 13/10/2026): the DTF pedido — its type from the item,
# its client the pedido's (D4), its fit on the film, the extra rows the
# client controls (D5), and confirming without splitting.
RSpec.describe "The DTF pedido", type: :request do
  let(:client) { create(:client, name: "Arcoverde Calçados") }
  let(:etiqueta) { criar_etiqueta_dtf(client: client, tamanhos: { "P" => [ 191, 201 ], "M" => [ 300, 300 ] }) }
  # Etapa 2.6c: no price, no confirming.
  before { Empresa.atual.update!(preco_metro_dtf: 120) }

  def adicionar(arquivo, grade, **extra)
    post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, grade: grade, **extra }, as: :json
    response.parsed_body
  end

  def entrar_como_cliente_final(cliente)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: funcao).user)
  end

  it "an etiqueta goes into its client's DTF draft, a calçado arte into another" do
    dtf = Pedido.find_by!(uuid: adicionar(etiqueta.arquivos.first, { "P" => 10 })["pedido_uuid"])
    calcado = Pedido.find_by!(uuid: adicionar(create(:arquivo, client: client), { "_total" => 2 })["pedido_uuid"])
    expect([ dtf.tipo, dtf.client, calcado.tipo ]).to eq([ "dtf", client, "calcado" ])
    expect(dtf.itens_pedido.first.item_pedido_pecas).to be_empty
    expect(adicionar(etiqueta.arquivos.first, { "M" => 5 })["pedido_uuid"]).to eq(dtf.uuid)
  end

  # A DTF is printed on the film: no material, whatever the request sends.
  it "never takes a material for an etiqueta" do
    material = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Oxford"), cor_material: CorMaterial.create!(nome: "Azul"), largura: "1.40", gramatura: "1g")
    pedido = Pedido.find_by!(uuid: adicionar(etiqueta.arquivos.first, { "P" => 1 }, materia_prima_uuid: material.uuid)["pedido_uuid"])
    expect(pedido.itens_pedido.first.materia_prima).to be_nil
  end

  it "refuses a size the etiqueta doesn't have, and an item of another type on a pedido's page" do
    expect(adicionar(etiqueta.arquivos.first, { "GG" => 1 })["error"]).to include("Sizes GG are not in this arte's grade; expected some of P, M")
    calcado = create(:pedido, client: client).tap { |p| create(:item_pedido, :com_quantidade, pedido: p) }
    expect(adicionar(etiqueta.arquivos.first, { "P" => 1 }, pedido_uuid: calcado.uuid)["error"]).to include("is a calcado pedido; #{etiqueta.titulo} goes into a dtf one")
  end

  it "shows each size's fit on the page and confirms without splitting, keeping the fit" do
    catalogo = criar_etiqueta_dtf(client: create(:client, name: "Outra"), no_catalogo: true)
    etiqueta.update!(girar_dtf: true) # it turns only when marked (16/10/2026)
    pedido = Pedido.find_by!(uuid: adicionar(etiqueta.arquivos.first, { "P" => 100 })["pedido_uuid"])
    adicionar(catalogo.arquivos.first, { "P" => 10 }, pedido_uuid: pedido.uuid)
    get resumo_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    linha = html.at_css(".pedido-dtf-linha[data-tamanho='P']")
    expect(%w[por-fileira fileiras impressas excedente metros].map { |c| linha.at_css(".pedido-dtf-#{c}").text.squish }).to eq([ "30 ↻", "4", "120", "+20", "0,071 m" ])
    # Calçado's price per pair isn't the DTF's (its charging is Etapa 2.6c).
    expect(response.body).not_to include("price per pair")
    post confirmar_pedido_path(pedido)
    expect(pedido.reload).to have_attributes(status: "confirmado", client: client)
    expect(Pedido.count).to eq(1)
    expect(pedido.itens_pedido.first.grades.first.encaixe_dtf).to include("impressas" => 120, "girada" => true)
  end

  it "blocks confirming without the pedido's client, or with another client's etiqueta outside the catálogo" do
    pedido = create(:pedido, tipo: "dtf")
    adicionar(etiqueta.arquivos.first, { "P" => 1 }, pedido_uuid: pedido.uuid)
    expect(pedido.bloqueios_confirmacao.map(&:tipo)).to eq(%i[pedido_sem_cliente etiqueta_de_outro_cliente])
    # Regression (dev, 13/10/2026): this pendência has no arte, and the panel's "abrir arte" made the page a 500.
    get resumo_pedido_path(pedido)
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css(".pedido-pendencia--pedido_sem_cliente a")["href"]).to eq("#pedido-cliente-dtf")
    patch dtf_pedido_path(pedido), params: { client_uuid: client.uuid }
    expect(pedido.reload.bloqueios_confirmacao).to be_empty
  end

  it "sets the delivery and the extra rows, the pedido's and a line's own" do
    pedido = Pedido.find_by!(uuid: adicionar(etiqueta.arquivos.first, { "P" => 32 })["pedido_uuid"])
    patch dtf_pedido_path(pedido), params: { entrega: "cortada", fileiras_extras: "2" }
    expect(pedido.reload.attributes.values_at("entrega", "fileiras_extras")).to eq([ "cortada", 2 ])
    item = pedido.itens_pedido.first
    patch dtf_fileiras_pedido_path(pedido), params: { item_uuid: item.uuid, tamanho_nome: "P", fileiras_extras: "0" }
    expect(EncaixeDoPedidoDtf.call(pedido).first.impressas).to eq(32)
    patch dtf_fileiras_pedido_path(pedido), params: { item_uuid: item.uuid, tamanho_nome: "P", fileiras_extras: "" }
    expect(EncaixeDoPedidoDtf.call(pedido).first.impressas).to eq(96)
  end

  it "the cliente final orders a catálogo etiqueta into his own draft, sets its extra rows but never the client" do
    outro = create(:client, name: "Dono VAZOU")
    catalogo = criar_etiqueta_dtf(client: outro, no_catalogo: true)
    entrar_como_cliente_final(client)
    get artes_para_adicionar_pedidos_path(format: :json, tipo: "dtf", q: catalogo.numero.to_s)
    expect(response.parsed_body["artes"].map { |a| [ a["titulo"], a["client"] ] }).to eq([ [ catalogo.titulo, nil ] ])
    pedido = Pedido.find_by!(uuid: adicionar(catalogo.arquivos.first, { "P" => 5 })["pedido_uuid"])
    expect([ pedido.client, pedido.tipo ]).to eq([ client, "dtf" ])
    patch dtf_pedido_path(pedido), params: { fileiras_extras: "1" }
    expect(pedido.reload.fileiras_extras).to eq(1)
    patch dtf_pedido_path(pedido), params: { client_uuid: outro.uuid }
    expect([ pedido.reload.client, flash[:alert] ]).to eq([ client, "The pedido's client is the team's to choose" ])
    get resumo_pedido_path(pedido)
    expect(response.body).not_to include("VAZOU", "girada")
  end

  it "a confirmed DTF pedido's settings are frozen" do
    pedido = Pedido.find_by!(uuid: adicionar(etiqueta.arquivos.first, { "P" => 1 })["pedido_uuid"])
    post confirmar_pedido_path(pedido)
    patch dtf_pedido_path(pedido), params: { fileiras_extras: "3" }
    expect([ pedido.reload.fileiras_extras, flash[:alert] ]).to eq([ 0, "#{pedido.rotulo_lixeira} is confirmado; it changes only while editable" ])
  end

  # The type comes from the first item: an empty draft offers both ways in, one modal.
  it "an empty draft offers the molde and the etiqueta search; a DTF pedido only the search" do
    vazio = create(:pedido)
    get resumo_pedido_path(vazio)
    html = Nokogiri::HTML(response.body)
    expect([ html.css(".add-to-order-dialog").size, html.css("[data-pedido-adicionar-target=molde]").size, html.css(".pedido-adicionar-busca").size ]).to eq([ 1, 1, 1 ])
    dtf = Pedido.find_by!(uuid: adicionar(etiqueta.arquivos.first, { "P" => 1 })["pedido_uuid"])
    get resumo_pedido_path(dtf)
    html = Nokogiri::HTML(response.body)
    expect([ html.css("[data-pedido-adicionar-target=molde]").size, html.css(".pedido-adicionar-busca").size ]).to eq([ 0, 1 ])
  end
end
