require "rails_helper"
require_relative "../support/etiquetas_dtf"

# Etapa 2.6c (decided 13-14/10/2026): the DTF's prices — the dono's, the ones
# agreed with a client, an etiqueta's agreed unit price, a pedido's edited
# ones — the team's with "ver valores"; a cliente final sees only what he pays.
RSpec.describe "The DTF's prices", type: :request do
  let(:client) { create(:client, name: "Arcoverde") }
  let(:etiqueta) { criar_etiqueta_dtf(client: client) }
  let(:arquivo) { etiqueta.arquivos.first }

  def entrar_como_cliente_final(valores_abertos: false)
    client.update!(visibilidade: { "valores" => valores_abertos })
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)
  end

  def pedido_com(quantidade)
    create(:pedido, client: client, tipo: "dtf").tap do |pedido|
      create(:item_pedido, pedido: pedido, arquivo: arquivo).grades.create!(tamanho_nome: "P", quantidade: quantidade)
    end
  end

  it "the dono sets the DTF's prices in Parâmetros, typed with a comma" do
    patch parametros_path, params: { empresa: { preco_metro_dtf: "120,50", preco_corte_dtf: "0,075", cobranca_dtf: "metro", cobrar_excedente_dtf: "false" } }
    expect(Empresa.atual.attributes.values_at("preco_metro_dtf", "preco_corte_dtf", "cobranca_dtf", "cobrar_excedente_dtf")).to eq([ 120.5, 0.075, "metro", false ])
  end

  it "the team agrees a client's prices on his page; blank follows the dono's" do
    get client_path(client)
    expect(response.body).to include('id="precos-dtf"')
    patch precos_dtf_client_path(client), params: { preco_metro_dtf: "110", preco_corte_dtf: "0,05", cobranca_dtf: "", cobrar_excedente_dtf: "false" }
    expect(client.reload.attributes.values_at("preco_metro_dtf", "preco_corte_dtf", "cobranca_dtf", "cobrar_excedente_dtf")).to eq([ 110, 0.05, nil, false ])
  end

  it "the team agrees an etiqueta size's unit price over the calculated, and goes back to it" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    get arquivo_path(arquivo)
    expect(Nokogiri::HTML(response.body).at_css(".arte-arquivo-preco-calculado").text).to eq("calculado R$ 0,07")
    patch arquivo_preco_dtf_path(arquivo), params: { preco_unidade_combinado: "0,10" }
    expect(arquivo.reload.preco_unidade_combinado).to eq(0.1)
    patch arquivo_preco_dtf_path(arquivo), params: { preco_unidade_combinado: "" }
    expect(arquivo.reload.attributes.values_at("preco_unidade_combinado", "preco_unidade_calculado")).to eq([ nil, 0.07 ])
  end

  it "the team edits a draft's charging and prices; confirming writes the starting and the charged" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    pedido = pedido_com(100)
    item = pedido.itens_pedido.first
    patch dtf_preco_linha_pedido_path(pedido), params: { item_uuid: item.uuid, tamanho_nome: "P", preco_unidade: "0,06" }
    get resumo_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    # The line's price sits in its etiqueta's table (decided 14/10/2026);
    # "Valores do pedido" sums the etiquetas, never repeating a size.
    linha = html.at_css(".pedido-item-dtf .pedido-dtf-linha[data-tamanho='P']")
    expect(%w[partida subtotal].map { |c| linha.at_css(".pedido-valores-#{c}").text.squish }).to eq([ "0,07", "R$ 7,20" ])
    expect(linha.at_css('input[name="preco_unidade"]')["value"]).to eq("0,06")
    expect(html.css("#valores-dtf .pedido-valores-linha").map { |tr| [ tr["data-parte"], tr.at_css(".pedido-valores-subtotal").text ] }).to eq([ [ "Etiquetas", "R$ 7,20" ] ])
    expect([ html.at_css("#valores-dtf .pedido-valores-desconto").text, html.at_css('[data-resumo="total"]').text ]).to eq([ "R$ 1,20", "R$ 7,20" ])
    post confirmar_pedido_path(pedido)
    expect(item.grades.first.reload.attributes.values_at("preco_unidade_partida", "preco_unidade")).to eq([ 0.07, 0.06 ])
    patch dtf_precos_pedido_path(pedido), params: { cobranca_dtf: "metro" }
    expect(pedido.reload.cobranca_dtf).to eq("quantidade")
  end

  it "switches a draft to charge by meter and edits the price per meter" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    pedido = pedido_com(100)
    patch dtf_precos_pedido_path(pedido), params: { cobranca_dtf: "metro", preco_metro: "100" }
    expect(ValoresDoPedidoDtf.call(pedido.reload).partes.map { |p| [ p.descricao, p.preco_partida, p.preco ] }).to eq([ [ "Filme", 120, 100 ] ])
  end

  it "blocks confirming while something has no price, pointing the dono to Parâmetros" do
    pedido = pedido_com(10)
    get resumo_pedido_path(pedido)
    pendencia = Nokogiri::HTML(response.body).at_css(".pedido-pendencia--sem_preco_dtf")
    expect(pendencia.text).to include("sem preço")
    expect(pendencia.at_css("a")["href"]).to eq(arquivo_path(arquivo))
  end

  it "a cliente final sees only what he pays, and sets no price anywhere" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    pedido = pedido_com(100)
    pedido.itens_pedido.first.grades.first.update!(preco_unidade: 0.06)
    entrar_como_cliente_final(valores_abertos: true)
    get resumo_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    # The starting price and the discount are the factory's business, in
    # the etiqueta's table too.
    expect([ html.at_css("#valores-dtf .pedido-valores-total").text, html.css(".pedido-valores-partida, .pedido-valores-desconto, .pedido-preco-form").size ]).to eq([ "R$ 7,20", 0 ])
    expect(html.at_css(".pedido-dtf-linha[data-tamanho='P'] .pedido-valores-preco").text.squish).to eq("R$ 0,06")
    get arquivo_path(arquivo)
    expect(response.body).not_to include("arte-arquivo-preco")
    patch dtf_preco_linha_pedido_path(pedido), params: { item_uuid: pedido.itens_pedido.first.uuid, tamanho_nome: "P", preco_unidade: "0,01" }
    patch precos_dtf_client_path(client), params: { preco_metro_dtf: "1" }
    patch arquivo_preco_dtf_path(arquivo), params: { preco_unidade_combinado: "0,01" }
    expect([ pedido.itens_pedido.first.grades.first.reload.preco_unidade, client.reload.preco_metro_dtf, arquivo.reload.preco_unidade_combinado ]).to eq([ 0.06, nil, nil ])
  end

  it "a cliente final with the values closed sees no price at all" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    pedido = pedido_com(100)
    entrar_como_cliente_final(valores_abertos: false)
    get resumo_pedido_path(pedido)
    # No price column in the etiqueta's table either, nor the panel's total.
    expect(response.body).not_to include("valores-dtf", "pedido-valores-subtotal", 'data-resumo="total"')
  end

  it "the team without \"ver valores\" sees the fit, no price" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    pedido = pedido_com(100)
    entrar_com_funcao(niveis: { "pedidos" => 2 })
    get resumo_pedido_path(pedido)
    expect([ response.body.include?("pedido-dtf-impressas"), response.body.include?("pedido-valores-subtotal") ]).to eq([ true, false ])
  end
end
