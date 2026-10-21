require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.3e (decided 20/10/2026): a metragem baixa adjusts the stock by the
# real — one measure per material when its lines take several — shown in the
# ledger (with its stage; "baixa desfeita: não conta" once undone), in the
# stage's baixa history and on the pedido's panel (out, adjustments, real).
RSpec.describe "The stock adjusted by the baixas", type: :request do
  let(:client) { create(:client, name: "Calçados Sul") }
  let(:oxford) { criar_tecido(grupo: "Oxford") }
  let(:helanca) { criar_tecido(grupo: "Helanca") }
  let(:papel) { criar_tecido(grupo: "Papel", cor: "Branco", tipo: "papel") }
  let(:pedido) do
    create(:pedido, tipo: "tecido", client: client).tap do |p|
      { oxford => 4, helanca => 6 }.each do |material, metros|
        arquivo = criar_obra_de_tecido("cor_lisa", client: client, no_catalogo: false, materia_prima: material, filename: "cor-#{material.id}").arquivos.first
        p.itens_pedido.create!(arquivo: arquivo, materia_prima: material, metros: metros)
      end
    end
  end

  before do
    (Empresa.atual || create(:empresa)).update!(papel_padrao: papel, preco_impressao_metro_tecido: 15)
    post confirmar_pedido_path(pedido)
  end

  def html = Nokogiri::HTML(response.body)
  def baixar(etapa, **campos) = post(pedido_baixas_path(pedido), params: { etapa: etapa, nivel: "pedido", confirmar: "1", **campos })
  def consumo = html.css("[data-resumo='consumo'] dd").map { |dd| dd.text.squish }

  it "asks one measure per fabric on the Calandra and shows the adjustment everywhere" do
    baixar("impressao", medida: "10")
    get producao_tecido_pedido_path(pedido, etapa: "calandra")
    expect(html.css(".etapa-andamento .baixa-material label").map(&:text)).to eq([ oxford, helanca ].map(&:nome_completo))

    baixar("calandra", medidas: { oxford.uuid => "4,4", helanca.uuid => "5,7" })
    expect(response.parsed_body).to eq("ok" => true)
    get producao_tecido_pedido_path(pedido, etapa: "calandra")
    expect(html.at_css(".historico-baixa [data-estoque]").text)
      .to eq("estoque: +0,4 m #{oxford.nome_completo} (Calçados Sul); −0,3 m #{helanca.nome_completo} (Calçados Sul)")

    get resumo_pedido_path(pedido)
    expect(consumo).to eq([ "saída 10 m", "saída 4 m · ajustes +0,4 m · real até agora 4,4 m", "saída 6 m · ajustes −0,3 m · real até agora 5,7 m" ])

    get movimentos_path
    expect(html.css(".movimento-etapa").map { |e| e.text.squish }).to eq([ "· Calandra" ] * 2)
  end

  it "stops counting an undone baixa's adjustment, saying so in the ledger" do
    baixar("impressao", medida: "11")
    baixa = pedido.baixas_producao.last
    delete pedido_baixa_path(pedido, baixa)
    get movimentos_path
    expect(html.at_css("[data-movimento='#{baixa.ajustes_estoque.first.uuid}'] .movimento-nao-conta").text).to eq("baixa desfeita: não conta")
    get resumo_pedido_path(pedido)
    expect(consumo.first).to eq("saída 10 m")
  end

  # Decided 20/10/2026: a pedido that took nothing at confirmation (before
  # Etapa 2.3d2) is not adjusted; its history says why.
  it "says a baixa of a pedido that took nothing left the stock alone" do
    MovimentoEstoque.where(pedido: pedido).delete_all
    baixar("impressao", medida: "11")
    baixar("calandra", medidas: { oxford.uuid => "5", helanca.uuid => "6" })
    get producao_tecido_pedido_path(pedido, etapa: "calandra")
    expect(html.at_css(".historico-baixa [data-estoque]").text).to eq("sem saída do estoque")
    expect(MovimentoEstoque.count).to eq(0)
  end

  # The empresa's paper is none of the client's business; his fabric is.
  it "shows a cliente final the consumption of his own fabric only" do
    baixar("impressao", medida: "11")
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)
    get resumo_pedido_path(pedido)
    expect(consumo).to eq([ "saída 4 m", "saída 6 m" ])
  end
end
