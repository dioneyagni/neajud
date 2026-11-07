require "rails_helper"
require_relative "../support/producao_tecido"

# Painel 3/4a (decided 07/11/2026): the impact window, the confirmation and
# what each pedido's history then says — the team's in the faixa and the
# resumo, a cliente final's only "previsão mudou".
RSpec.describe "Mover na fila", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  # Wednesday, 10:00.
  before { travel_to Time.zone.parse("2026-11-04 10:00") }

  let!(:primeiro) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: 2.hours.ago) } }
  let!(:segundo) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: 1.hour.ago) } }

  before do
    Turno.create!(nome: "Dia", inicio: "00:00", fim: "23:59", dias: (0..6).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: 31)
  end

  def html
    Nokogiri::HTML(response.body)
  end

  it "shows the move's impact in its frame, then saves it and closes" do
    get impacto_na_fila_path(pedido: segundo.uuid, etapa: "impressao", posicao: 1)

    expect(response).to have_http_status(:ok)
    expect(html.css("turbo-frame#painel_impacto h3").text).to eq("##{segundo.uuid.first(8)} · Impressão: 2º → 1º")
    expect(html.css("[data-impacto-empurrado]").map { |e| e["data-impacto-empurrado"] }).to eq([ primeiro.uuid ])
    expect(html.css("#impacto-posicao option").map(&:text)).to eq(%w[1º 2º])

    post movimentos_da_fila_path, params: { pedido: segundo.uuid, etapa: "impressao", posicao: 1, motivo: "urgente" }
    expect(html.css("[data-impacto-feito]").text).to eq("1 movimento salvo.")
    expect(MovimentoDaFila.sole.slice(:pedido_id, :de, :para, :motivo, :user_id)).to eq("pedido_id" => segundo.id, "de" => 2, "para" => 1, "motivo" => "urgente", "user_id" => @usuario_logado.id)
  end

  it "asks the reason again when someone comes to be late, keeping what was typed" do
    primeiro.update!(prazo_entrega: Date.current)
    # A short day: printed second, the first one's Impressão spills into Thursday.
    Turno.sole.update!(inicio: "10:00", fim: "11:40")
    get impacto_na_fila_path(pedido: segundo.uuid, etapa: "impressao", posicao: 1)
    expect(html.css("[data-passa-a-atrasar=true]").map { |e| e["data-impacto-empurrado"] }).to eq([ primeiro.uuid ])

    post movimentos_da_fila_path, params: { pedido: segundo.uuid, etapa: "impressao", posicao: 1, motivo: "" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(html.css(".painel-impacto-erro").text).to eq("##{primeiro.uuid.first(8)} would come to be late: say why")
    expect(MovimentoDaFila.count).to eq(0)
  end

  # Q9a: the arrows are for who programs the production.
  it "shows ↑ ↓ only to who programs the production" do
    get painel_path
    expect(html.css("[data-fila-setor=impressao] [data-fila-pedido='#{segundo.uuid}'] [data-mover]").map { |a| a["data-mover"] }).to eq(%w[subir])
    entrar_com_funcao(niveis: { "pedidos" => 3 }, acoes: %w[atualizar_producao])
    get painel_path
    expect(html.css("[data-fila-setor] [data-mover], .painel-fila-voltar")).to be_empty
  end

  it "refuses a stage under way, saying why" do
    RegistrarBaixaService.call(primeiro, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
    RegistrarBaixaService.call(segundo, etapa: "impressao", nivel: "linha", alvo: EstadoDasEtapas.call(segundo)["impressao"].keys.first, medida: "12,5", confirmar: true)
    get impacto_na_fila_path(pedido: segundo.uuid, etapa: "impressao", posicao: 1)
    expect([ response.status, html.css(".painel-impacto-erro").text ]).to eq([ 422, "Impressão of pedido #{segundo.uuid} is under way (a baixa was given); it can't move" ])
  end

  it "shows the move in each pedido's programação history, and the moved line's badge in its queue" do
    post movimentos_da_fila_path, params: { pedido: segundo.uuid, etapa: "impressao", posicao: 1, motivo: "urgente" }

    get painel_path
    linha = html.css("[data-fila-setor=impressao] [data-fila-pedido='#{segundo.uuid}'] [data-fila-movida]").sole
    expect(linha.text.squish).to start_with("↑ movida · #{@usuario_logado.nome}")
    historico = html.css("#painel_#{primeiro.uuid} > .painel-faixa [data-historico-programacao] p").sole.text
    expect(historico).to match(/#{@usuario_logado.nome} passou o ##{segundo.uuid.first(8)} à frente na Impressão \(2º → 1º\) · urgente · este pedido: /)
    get resumo_pedido_path(segundo)
    expect(html.css("[data-historico-programacao] li").sole.text).to include("passou à frente de 1 pedido")
  end

  # Q4: a cliente final learns only that his previsão moved to another day.
  it "shows a cliente final no programação, only the history's \"previsão mudou\"" do
    primeiro.eventos_pedido.create!(user: @usuario_logado, tipo: "previsao_mudou", recado: "qua 04/11 → qui 05/11")
    MovimentoDaFila.create!(pedido: segundo, user: @usuario_logado, etapa: "impressao", setor: "impressao", de: 2, para: 1, ordem_em: 3.hours.ago,
                            motivo: "urgente", empurrados: [ { "pedido_id" => primeiro.id, "de" => Time.current.iso8601, "para" => 1.day.from_now.iso8601 } ])
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: primeiro.client, funcao: funcao).user)

    get resumo_pedido_path(primeiro)
    expect(html.css(".pedido-eventos li span").map(&:text)).to eq([ "previsão mudou: qua 04/11 → qui 05/11 (reprogramação da fábrica)" ])
    expect(response.body).not_to include("urgente")
    get painel_path
    expect(html.css("[data-historico-programacao]")).to be_empty
  end
end
