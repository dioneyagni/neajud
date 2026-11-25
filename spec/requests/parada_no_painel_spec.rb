require "rails_helper"
require_relative "../support/producao_tecido"

# Máquinas 3/5b (decided 24–25/11/2026, canvas "Máquinas", 7–8): the ⏸ on
# a machine's lane opens the new stop's window — the stage and the machine
# picked, today to today, the other stages it stops too and the pieces
# waiting for it, before saving —; saved, the warning in the window. A
# stopped lane says until when and by which stop, with "Voltou a
# funcionar"; the header counts it; a piece held or started on it says it
# waits, "máquina parada". A tecido pedido runs its Calandra here.
RSpec.describe "Parada no Painel", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  # Wednesday, 10:00.
  before { travel_to Time.zone.parse("2026-11-04 10:00") }

  let!(:pedido) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: 2.hours.ago) } }
  let!(:lenta) { maquina("Calandra 2", calandra: 15.5, dublagem: 30) }
  let!(:rapida) { maquina("Calandra 3", calandra: 31) }

  before do
    Turno.create!(nome: "Dia", inicio: "00:00", fim: "23:59", dias: (0..6).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
  end

  def maquina(nome, **velocidades)
    Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
  end

  def html = Nokogiri::HTML(response.body)
  def raia(maquina) = html.at_css("[data-fila-setor=estamparia] [data-fila-raia='#{maquina.uuid}']")
  def linha = html.at_css("[data-fila-setor=estamparia] [data-fila-pedido='#{pedido.uuid}']")

  def parar(maquina, ate: Date.current + 2)
    ExcecaoCalendario.new(nome: "Manutenção da #{maquina.nome}", data: Date.current, data_fim: ate, etapa: "calandra", user: @usuario_logado).tap do |parada|
      parada.paradas_das_maquinas.build(maquina: maquina)
      parada.save!
    end
  end

  it "offers ⏸ on each lane, and its window opens on the stage and the machine, saying what waits for it" do
    MovimentoDaFila.create!(pedido: pedido, user: @usuario_logado, etapa: "calandra", setor: "estamparia", de_maquina: rapida, para_maquina: lenta)
    get painel_path
    expect(raia(lenta).at_css(".painel-raia-parar")["href"]).to eq(nova_parada_no_painel_path(maquina: lenta.uuid, setor: "estamparia"))

    get nova_parada_no_painel_path(maquina: lenta.uuid, setor: "estamparia")
    expect(html.at_css("turbo-frame#painel_impacto h3").text).to eq("Parar a Calandra 2")
    expect([ html.at_css("input[name='excecao[etapa]']")["value"], html.at_css("#parada_data")["value"], html.at_css("#parada_data_fim")["value"] ]).to eq([ "calandra", "2026-11-04", "2026-11-04" ])
    expect(html.css(".parada-maquina").map { |l| [ l.text.squish, l.at_css("input").key?("checked") ] }).to eq([ [ "Calandra 2", true ], [ "Calandra 3", false ] ])
    expect(html.at_css("[data-parada-previa]").text.squish).to eq("A Calandra 2 também faz Dublagem: ela para lá também. 1 peça presa nela espera ela voltar.")
  end

  it "saves the stop from the window, showing the warning there" do
    post paradas_no_painel_path, params: { maquina: rapida.uuid, setor: "estamparia",
                                           excecao: { nome: "Feltro", data: "2026-11-04", data_fim: "2026-11-04", etapa: "calandra", maquina_uuids: [ rapida.uuid ] } }
    expect([ response.status, ExcecaoCalendario.sole.maquinas, html.at_css("[data-parada-feita] [data-parada-aviso]").text.squish ])
      .to eq([ 200, [ rapida ], "Feltro (qua 04/11) salva. Ninguém passa a atrasar." ])

    post paradas_no_painel_path, params: { maquina: rapida.uuid, setor: "estamparia", excecao: { nome: "", data: "2026-11-04", etapa: "calandra" } }
    expect([ response.status, html.at_css(".painel-impacto-erro").text, ExcecaoCalendario.count ]).to eq([ 422, "Nome can't be blank", 1 ])
  end

  it "shows a stopped lane until when, counts it, and lets it come back to work from there" do
    parada = parar(rapida)
    get painel_path
    expect(raia(rapida).at_css("[data-raia-parada]").text.squish).to eq("⏸ parada até sex 06/11 · Manutenção da Calandra 3 · #{@usuario_logado.nome}")
    expect([ raia(rapida).at_css(".painel-raia-parar"), raia(lenta).at_css("[data-raia-parada]") ]).to eq([ nil, nil ])
    expect(html.at_css("[data-fila-setor=estamparia] [data-fila-paradas]").text).to eq(", 1 parada")

    raia(rapida).at_css("form.painel-raia-form").then { |form| patch form["action"] }
    expect([ response, parada.reload.voltou_por ]).to match([ redirect_to(painel_path), @usuario_logado ])
    get painel_path
    expect(raia(rapida).at_css("[data-raia-parada]")).to be_nil
  end

  it "says a piece held on a stopped machine waits for it" do
    MovimentoDaFila.create!(pedido: pedido, user: @usuario_logado, etapa: "calandra", setor: "estamparia", de_maquina: lenta, para_maquina: rapida)
    parar(rapida)
    get painel_path
    expect(linha.at_css("[data-fila-presa]").text).to start_with("● presa na Calandra 3 · parada até sex 06/11 · ")
    expect(linha.at_css("[data-fila-maquina-parada]").text).to eq("máquina parada")
  end

  it "says a piece started on a stopped machine waits for it" do
    RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
    alvo = EstadoDasEtapas.call(pedido)["calandra"].keys.first
    RegistrarBaixaService.call(pedido, etapa: "calandra", nivel: "linha", alvo: alvo, medida: "12,5", confirmar: true, maquina: rapida.uuid, user: @usuario_logado)
    parar(rapida)
    get painel_path
    expect([ linha.at_css("[data-fila-espera-maquina]").text, linha.at_css("[data-fila-maquina-parada]").text ]).to eq([ "começada na Calandra 3 · espera ela voltar", "máquina parada" ])
  end
end
