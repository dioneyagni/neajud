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
end
