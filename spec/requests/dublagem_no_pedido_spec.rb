require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5b1c1 (decided 11/11/2026): the pages of a tecido pedido whose
# item is dubbed in it — its Dublagem stages linked from the pedido, a line
# per item × letra, and the item saying which letras each stage makes.
RSpec.describe "Dublagem no pedido", type: :request do
  let(:construcao) { construcao_dublada_no_pedido }
  let(:pedido) { pedido_dublado_confirmado(construcao, metros: 10) }

  def html = Nokogiri::HTML(response.body)

  it "links its four stages and says on the item which letras each makes" do
    get resumo_pedido_path(pedido)

    expect(html.css(".etapas-nav a, .pedido-ir-producao a").map { |link| link["href"] }.uniq)
      .to include(*%w[impressao dublagem calandra dublagem_final].map { |etapa| producao_tecido_pedido_path(pedido, etapa: etapa) })
    expect(html.at_css("[data-dublagem-producao]").text).to eq("dublado no pedido: DUB-A, DUB-B, DUB-C (Dublagem) · DUB-D (Dublagem final)")
  end

  it "shows a line per letra, the one waiting saying for which" do
    get producao_tecido_pedido_path(pedido, etapa: "dublagem")

    linhas = html.css("tr[data-letra]")
    expect(linhas.map { |linha| linha["data-letra"] }).to eq(%w[DUB-A DUB-B DUB-C])
    expect(linhas.last.text.squish).to include("DUB-B / Espuma TC4 Branco", "10 m")
    expect(linhas.last.at_css(".etapa-situacao").text.squish).to include("DUB-B")

    get producao_tecido_pedido_path(pedido, etapa: "dublagem_final")
    expect(html.at_css("tr[data-letra]").text.squish).to include("DUB-D", "DUB-A / DUB-C")
  end

  # 5b1c3 (Q2a/Q3a): the Espuma missing, DUB-B and DUB-C say so on the
  # stage's page; the Painel's Dublagem queue goes with DUB-A, saying which wait.
  it "says on a held letra's line what it waits for, and the queue which letras wait" do
    espuma = construcao.camadas_em_ordem.third.materia_prima
    ComponentesDaDublagem.new(construcao).reject { |componente| componente.materia_prima == espuma }.each do |componente|
      MovimentoEstoque.create!(materia_prima: componente.materia_prima, client: componente.client, da_empresa: componente.client.nil?, tipo: "entrada", quantidade: 10 * componente.por_metro)
    end
    sem_espuma = pedido_dublado_confirmado(construcao, metros: 10, estoque: false)

    get producao_tecido_pedido_path(sem_espuma, etapa: "dublagem")
    avisos = html.css("tr[data-letra]").to_h { |linha| [ linha["data-letra"], linha.at_css("[data-falta-da-letra]")&.text ] }
    expect(avisos).to eq("DUB-A" => nil, "DUB-B" => "aguarda #{espuma.nome_completo} da empresa · faltam 20 m", "DUB-C" => "aguarda #{espuma.nome_completo} da empresa · faltam 20 m")

    get painel_path
    vez = html.at_css("[data-fila-setor=dublagem] [data-fila-pedido='#{sem_espuma.uuid}']")
    expect(vez.at_css("[data-fila-o-que]").text).to eq("1 letra · Dublagem: ##{sem_espuma.uuid.first(8)}|DUB-A")
    expect(vez.at_css("[data-fila-retidas]").text).to eq("DUB-B, DUB-C aguardam #{espuma.nome_completo}")
  end
end
