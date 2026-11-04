require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5a (decided 03-04/11/2026): the Dublagens page — em aberto, the
# ordens generated, done and cancelled — and the pedido waiting for its
# dublado ("Aguardando: dublagem").
RSpec.describe "Ordens de dublagem", type: :request do
  let(:client) { create(:client, name: "Malharia Sul") }
  let(:oxford) { material_de_dublagem("Oxford", largura: "1.60 m") }
  let(:lona) { material_de_dublagem("Lona", largura: "1.40 m") }
  let(:filme) { material_de_dublagem("Filme", tipo: "filme", micras: 35) }
  let(:construcao) { montar_construcao([ oxford, "trama" ], [ lona, filme ], preco_final: 46).tap(&:save!) }
  let!(:pedido) { pedido_dublado_confirmado(construcao, metros: 10, client: client) }

  def pagina(caminho = dublagens_path)
    get caminho
    Nokogiri::HTML(response.body)
  end

  it "lists what the pedidos miss, warning about the components the stock doesn't cover" do
    MovimentoEstoque.create!(materia_prima: oxford, da_empresa: true, tipo: "entrada", quantidade: 4)
    aberta = pagina.at_css("[data-dublagem-aberta]")

    expect(aberta.at_css("[data-falta]").text).to eq("10 m")
    expect(aberta.at_css(".dublagem-pedidos a")["href"]).to eq(resumo_pedido_path(pedido))
    expect(aberta.at_css("[data-falta-componente]").text).to eq("falta componente: #{oxford.nome_completo} da empresa, 6 m; #{lona.nome_completo} da empresa, 10 m; #{filme.nome_completo} da empresa, 10 m")
  end

  it "counts an ordem of part of the falta, leaving the rest em aberto" do
    post dublagens_path, params: { construcao_uuid: construcao.uuid, metros: "4" }
    aberta = pagina.at_css("[data-dublagem-aberta]")

    expect(aberta.at_css("[data-falta]").text).to eq("6 m")
    expect(aberta.at_css(".dublagem-metros").text.squish).to eq("Faltam 6 m · 4 m já em ordem")
  end

  it "generates an ordem, marks it done with the real meters — the pedido stops waiting — or cancels one" do
    post dublagens_path, params: { construcao_uuid: construcao.uuid, metros: "12,5" }
    ordem = OrdemDublagem.last
    expect([ ordem.metros.to_f, ordem.gerada_por, flash[:notice] ]).to eq([ 12.5, @usuario_logado, "Ordem de dublagem ##{ordem.uuid.first(8)} gerada: 12,5 m de #{construcao.nome}." ])
    expect(pagina.at_css("[data-dublagem-aberta]")).to be_nil

    patch feita_dublagem_path(ordem), params: { metros: "12" }
    expect([ ordem.reload.status, SaldosDeEstoque.call.empresa(construcao.materia_prima) ]).to eq([ "feita", 2.0 ])
    expect(pagina(resumo_pedido_path(pedido)).at_css("[data-resumo=aguardando]")).to be_nil

    outra = OrdemDublagem.create!(construcao: construcao, metros: 3)
    patch cancelar_dublagem_path(outra)
    expect([ outra.reload.status, outra.cancelada_por, outra.movimentos_estoque.count ]).to eq([ "cancelada", @usuario_logado, 0 ])
  end

  it "says why an ordem isn't generated or marked done" do
    post dublagens_path, params: { construcao_uuid: construcao.uuid, metros: "0" }
    expect(flash[:alert]).to eq("Metros must be more than 0 m (got 0)")

    feita = OrdemDublagem.create!(construcao: construcao, metros: 3).tap { |o| o.marcar_feita!(metros: 3, user: nil) }
    patch feita_dublagem_path(feita), params: { metros: "3" }
    expect(flash[:alert]).to eq("Status is feita: only a generated ordem can be marked done")
  end

  it "the pedido waits for dublagem: the team sees the dublado, on the panel, the list and the Calandra" do
    html = pagina(resumo_pedido_path(pedido))
    expect(html.at_css("[data-resumo=aguardando]").text.squish).to eq("Aguardando: dublagem de #{construcao.nome} · faltam 10 m")

    expect(pagina(pedidos_tecido_path).at_css("[data-aguardando]").text).to eq("aguardando dublagem")
    calandra = pagina(producao_tecido_pedido_path(pedido, etapa: "calandra"))
    expect(calandra.at_css(".producao-tecido-material").text.squish).to eq("#{construcao.nome} aguardando dublagem: 10 m")
  end

  # Decision 3a: the ordens are the factory's — a cliente final only reads
  # that his pedido waits for the dublagem, never the layers nor the meters.
  it "a cliente final sees only 'dublagem', and never the Dublagens page" do
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)

    expect(pagina(resumo_pedido_path(pedido)).at_css("[data-resumo=aguardando]").text.squish).to eq("Aguardando: dublagem")
    get dublagens_path
    expect(response).to have_http_status(:forbidden)
  end
end
