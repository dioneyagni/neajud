require "rails_helper"
require_relative "../support/tecidos"

# Decided 20/10/2026, the layout of the cor lisa canvas: the tecido pedidos'
# own list (cards per status that count and filter, a search, the arte's
# swatch, fabrics, meters, value, "Repetir") and "Repetir pedido" (a new
# draft with the meters of this time and the prices charged, warned below
# today's to the team).
RSpec.describe "The tecido pedidos' list and repeating one", type: :request do
  let(:client) { create(:client, name: "Malharia Sul") }
  let(:outro) { create(:client, name: "Confecções Norte") }
  let(:oxford) { criar_tecido(grupo: "Oxford") }
  let!(:entregue) { pedido_de(client, status: "entregue", metros: 12) }
  let!(:rascunho) { pedido_de(outro, status: "rascunho", metros: 5) }

  before { (Empresa.atual || create(:empresa)).update!(preco_impressao_metro_tecido: 15) }

  def pedido_de(cliente, status:, metros:)
    create(:pedido, tipo: "tecido", client: cliente).tap do |p|
      arquivo = criar_obra_de_tecido("cor_lisa", client: cliente, no_catalogo: false, materia_prima: oxford, filename: "cor-#{cliente.id}").arquivos.first
      p.itens_pedido.create!(arquivo: arquivo, materia_prima: oxford, metros: metros, preco_impressao_metro: 14)
      ValoresDoPedidoTecido.gravar!(p) unless status == "rascunho"
      p.update!(status: status)
    end
  end

  def html = Nokogiri::HTML(response.body)
  def linhas = html.css("tr[data-pedido]").map { |tr| tr["data-pedido"] }
  def contagem(status) = html.at_css(".tecido-cartao[data-status='#{status}'] .tecido-cartao-contagem").text.to_i

  def entrar_como_cliente_final(cliente)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: funcao).user)
  end

  it "lists the tecido pedidos with cards that count and filter, and searches" do
    create(:pedido, tipo: "calcado", client: client)
    get pedidos_tecido_path
    expect(linhas).to contain_exactly(entregue.uuid, rascunho.uuid)
    expect([ contagem("entregue"), contagem("rascunho"), contagem("confirmado") ]).to eq([ 1, 1, 0 ])
    expect(html.at_css("tr[data-pedido='#{entregue.uuid}'] [data-metros]").text).to eq("12 m")
    expect(html.at_css("tr[data-pedido='#{entregue.uuid}'] [data-valor]").text).to eq("R$ 168,00")
    expect(html.css("tr[data-pedido='#{rascunho.uuid}'] .tecido-repetir")).to be_empty

    get pedidos_tecido_path(status: "entregue")
    expect([ linhas, html.at_css(".tecido-cartao[aria-current='page']")["data-status"] ]).to eq([ [ entregue.uuid ], "entregue" ])
    get pedidos_tecido_path(q: "norte")
    expect(linhas).to eq([ rascunho.uuid ])
    get pedidos_tecido_path(q: entregue.uuid.first(6))
    expect(linhas).to eq([ entregue.uuid ])
  end

  it "shows a cliente final his own, without values unless open to him" do
    entrar_como_cliente_final(client)
    get pedidos_tecido_path
    expect(linhas).to eq([ entregue.uuid ])
    expect(html.css("[data-valor]")).to be_empty
    # The search's branch by item is visible too: the other client's name finds nothing.
    get pedidos_tecido_path(q: "norte")
    expect(linhas).to eq([])
    get pedidos_tecido_path(q: "cor-#{outro.id}")
    expect(linhas).to eq([])
  end

  it "repeats a pedido: the meters of this time, the prices charged, warned below today's" do
    item = entregue.itens_pedido.first
    get repetir_pedido_path(entregue)
    expect(html.at_css("#repetir-metros-#{item.uuid}")["value"]).to eq("12")
    expect(html.at_css("[data-preco-abaixo]").text).to eq("Impressão R$ 14,00/m — abaixo do valor de hoje (R$ 15,00/m)")

    expect { post repetir_pedido_path(entregue), params: { metros: { item.uuid => "24,5" } } }.to change(Pedido, :count).by(1)
    novo = Pedido.order(:id).last
    expect(response).to redirect_to(pedido_path(novo))
    expect(flash[:notice]).to eq("Rascunho criado a partir do ##{entregue.uuid.first(8)}.")
    expect(novo.itens_pedido.map { |i| [ i.metros.to_f, i.preco_impressao_metro.to_f ] }).to eq([ [ 24.5, 14.0 ] ])
    get resumo_pedido_path(novo)
    expect(html.at_css("[data-precos-abaixo]").text).to start_with("1 item com preço abaixo do valor de hoje")
  end

  it "refuses invalid meters and a pedido that can't be repeated, saying why" do
    post repetir_pedido_path(entregue), params: { metros: { entregue.itens_pedido.first.uuid => "doze" } }
    expect(flash[:alert]).to eq('Meters "doze" are not numbers; expected meters like 12,5')
    post repetir_pedido_path(rascunho)
    expect(flash[:alert]).to eq("Could not repeat ##{rascunho.uuid.first(8)}: Only a confirmed tecido pedido is repeated (confirmado, em_producao, entregue); this one is rascunho")
    get repetir_pedido_path(rascunho)
    expect(html.at_css("[data-repetir-erro]")).to be_present
    expect(html.css("form.tecido-repetir-form")).to be_empty
  end

  # Another client's pedido is not his to see, let alone repeat (Visibilidade).
  it "answers 404 to a cliente final repeating another client's pedido" do
    entrar_como_cliente_final(outro)
    get repetir_pedido_path(entregue)
    expect(response).to have_http_status(:not_found)
  end
end
