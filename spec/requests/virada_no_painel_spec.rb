require "rails_helper"
require_relative "../support/producao_tecido"

# Painel 3/4b (decided 07/11/2026): after a virada, the Painel says who came
# to be late (Q5a), where each stage came from (Q3a), the history (Q6a) and
# the load over 100% (Q7a) — to the team only. The factory works a Manhã,
# 08:00–12:00; nothing was done on Wednesday.
RSpec.describe "A virada no Painel", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:quinta) { Time.zone.parse("2026-11-05 08:00") }
  let!(:pedidos) do
    travel_to(quarta - 3.hours) { Array.new(3) { |i| pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - (3 - i).hours) } } }
  end
  let(:primeiro) { pedidos.first }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: 31)
    primeiro.update!(prazo_entrega: quarta.to_date)
    [ quarta, quinta ].each { |agora| travel_to(agora) { TirarFotoDaFila.call } }
    # Thursday 10:00: the Manhã's 3 h of Impressão programmed, 2 h left, none done.
    travel_to quinta + 2.hours
  end

  def html
    Nokogiri::HTML(response.body)
  end

  it "warns who came to be late, marks where each stage came from, and the load past 100%" do
    get painel_path

    expect(html.css("[data-painel-virada] strong").text).to eq("Na virada para a Manhã, 1 pedido passou a atrasar:")
    expect(html.css("[data-painel-virada] button").map { |b| b["data-pedido"] }).to eq([ primeiro.uuid ])
    fila = html.css("[data-fila-setor=impressao]").sole
    expect(fila.css("[data-fila-pedido='#{primeiro.uuid}'] [data-fila-veio]").text).to eq("veio de ontem · Manhã")
    expect(fila.css(".painel-fila-turno-carga").first.then { |c| [ c["data-fila-carga"], c["class"].include?("estourada"), c["title"] ] })
      .to eq([ "150", true, "o programado para este turno não cabe: 3 h em 2 h" ])
    celula = html.css("#painel_#{primeiro.uuid} > .painel-linha [data-coluna=impressao]").sole
    expect([ celula.key?("data-adiada"), celula["title"] ]).to eq([ true, "Impressão: veio de ontem · Manhã" ])
    expect(html.css("[data-tempo-carga=impressao] .painel-tempo-carga--estourado").text).to eq("150%")
    expect(html.css("#painel_#{primeiro.uuid} [data-historico-programacao]").text).to include("virada para a Manhã · não terminaram na Manhã: Impressão do ##{primeiro.uuid.first(8)}")
  end

  # 3/4b2 (Q8a, Q9a): the second pedido was to print in Wednesday's Manhã,
  # held by the first's Impressão, holding the third's.
  it "draws the faixa's first plan and its arrow, and lists who crossed it" do
    segundo, terceiro = pedidos.second, pedidos.third
    get painel_path
    faixa = html.css("#painel_#{segundo.uuid} > .painel-faixa").sole

    expect(faixa.css("[data-tdp-coluna]").map { |c| [ c.text.squish, c["class"].include?("passada") ] }).to eq([ [ "qua 04/11Manhã", true ], [ "qui 05/11Manhã", false ], [ "sex 06/11Manhã", false ] ])
    expect(faixa.css("[data-tdp-plano]").map { |p| p["style"] }).to eq([ "width: 25%", "width: 13%" ])
    expect(faixa.css("[data-tdp-seta]").map { |s| [ s["data-tdp-seta"], s.text.squish ] }).to eq([ [ "1", "+1 turno" ], [ "2", "+2 turnos" ] ])

    botao = faixa.css("[data-quem-cruzou] button").sole
    expect([ botao.text, botao["data-cruzou"].split.sort ]).to eq([ "mostrar quem cruzou (2)", [ primeiro.uuid, terceiro.uuid ].sort ])
    linhas = faixa.css("[data-cruzamento]").map(&:text)
    expect(linhas).to include("##{primeiro.uuid.first(8)} empurrou este pedido · 05/11 · não terminou a Impressão na Manhã",
                              "este pedido empurrou o ##{terceiro.uuid.first(8)} · 05/11 · a Calandra deste não terminou na Manhã")
    expect(linhas.size).to eq(4)
  end

  it "shows the cliente final's \"previsão mudou\", from no one, in the pedido's history" do
    get resumo_pedido_path(primeiro)

    expect(response).to have_http_status(:ok)
    expect(html.css(".pedido-evento--previsao_mudou").text).to include("qua 04/11 → qui 05/11")
  end

  # Q5a, Q6a: the viradas, the photos and the marks are the factory's.
  it "shows a cliente final none of it" do
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: primeiro.client, funcao: funcao).user)
    get painel_path

    expect(response).to have_http_status(:ok)
    expect(html.css("[data-painel-virada], [data-fila-veio], [data-adiada], [data-historico-programacao], [data-quem-cruzou], [data-tdp-plano], [data-tdp-seta]")).to be_empty
  end
end
