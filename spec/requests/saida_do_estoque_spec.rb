require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.3d2 (decided 19/10/2026): confirming takes the pedido's materials
# from the stock; a pedido whose out passes what came in waits for material
# — on the list (badge and filter), on its panel and on Materials. A cliente
# final sees that his pedido waits, and the meters of his own fabric only.
RSpec.describe "A pedido's stock out", type: :request do
  let(:client) { create(:client, name: "Calçados Sul") }
  let(:oxford) { criar_tecido(grupo: "Oxford") }
  let(:papel) { criar_tecido(grupo: "Papel", cor: "Branco", tipo: "papel") }
  let(:pedido) do
    create(:pedido, tipo: "tecido", client: client).tap do |p|
      p.itens_pedido.create!(arquivo: criar_obra_de_tecido("cor_lisa", client: client, no_catalogo: false, materia_prima: oxford).arquivos.first, materia_prima: oxford, metros: 4)
    end
  end

  before { (Empresa.atual || create(:empresa)).update!(papel_padrao: papel, preco_impressao_metro_tecido: 15) }

  def html = Nokogiri::HTML(response.body)

  def confirmado
    post confirmar_pedido_path(pedido)
    expect(flash[:alert]).not_to start_with("Não é possível") if flash[:alert]
    pedido.reload
  end

  def entrar_como_cliente_final
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)
  end

  it "confirming takes the fabric from its owner and the paper from the empresa, once" do
    confirmado
    expect(pedido.movimentos_estoque.map { |m| [ m.materia_prima, m.client, m.tipo, m.quantidade.to_f ] })
      .to contain_exactly([ papel, nil, "saida", 4.0 ], [ oxford, client, "saida", 4.0 ])
    expect(flash[:alert]).to be_nil
    expect { post confirmar_pedido_path(pedido) }.not_to change(MovimentoEstoque, :count)
  end

  it "warns on confirming about what took nothing, never blocking" do
    Empresa.atual.update!(papel_padrao: nil)
    expect(confirmado.status).to eq("confirmado")
    expect(flash[:alert]).to eq("No stock out: Impressão: no paper chosen and no default one in Parâmetros.")
  end

  it "shows the waiting pedido on the list, its filter, its panel, Materials and the ledger" do
    MovimentoEstoque.create!(materia_prima: oxford, client: client, tipo: "entrada", quantidade: 1)
    confirmado
    get pedidos_path(aguardando: 1)
    expect(html.css("tr[data-pedido-uuid], tbody tr").map(&:text).join).to include("aguardando material")
    expect(html.at_css("[data-status='aguardando'][aria-current='page']")).to be_present
    get resumo_pedido_path(pedido)
    expect(html.at_css("[data-resumo='aguardando']").text.squish)
      .to eq("Aguardando: #{oxford.nome_completo} do cliente · faltam 3 m; #{papel.nome_completo} da empresa · faltam 4 m")
    get materiais_path
    expect(html.at_css("tr[data-material='#{oxford.uuid}'] [data-aguardando]").text).to eq("Aguardando: 1 pedido · faltam 3 m")
    expect(html.css("[data-pedido='#{pedido.uuid}'] a").map(&:text)).to eq([ "##{pedido.uuid.first(8)}" ] * 2)
  end

  it "drops a pedido from the filter once an entry covers it" do
    confirmado
    MovimentoEstoque.create!(materia_prima: oxford, client: client, tipo: "entrada", quantidade: 4)
    MovimentoEstoque.create!(materia_prima: papel, da_empresa: true, tipo: "entrada", quantidade: 4)
    get pedidos_path(aguardando: 1)
    expect(html.css("[data-aguardando]")).to be_empty
    get resumo_pedido_path(pedido)
    expect(html.at_css("[data-resumo='aguardando']")).to be_nil
  end

  # The empresa's paper and stock are none of the client's business; whether
  # his pedido waits, and for how much of his own fabric, is.
  it "shows a cliente final that his pedido waits, with the meters of his own fabric only" do
    MovimentoEstoque.create!(materia_prima: oxford, client: client, tipo: "entrada", quantidade: 4)
    confirmado
    entrar_como_cliente_final
    get resumo_pedido_path(pedido)
    expect(html.at_css("[data-resumo='aguardando']").text.squish).to eq("Aguardando: material")
    MovimentoEstoque.where(tipo: "entrada").delete_all
    get resumo_pedido_path(pedido)
    expect(html.at_css("[data-resumo='aguardando']").text.squish).to eq("Aguardando: #{oxford.nome_completo} do cliente · faltam 4 m")
    get materiais_path
    expect([ papel, oxford ].map { |m| html.at_css("tr[data-material='#{m.uuid}'] [data-aguardando]")&.text }).to eq([ nil, "Aguardando: 1 pedido · faltam 4 m" ])
  end
end
