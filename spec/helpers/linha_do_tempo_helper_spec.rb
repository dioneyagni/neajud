require "rails_helper"

# Painel 2/4c: what a bar's end says, a day's load and the window's address.
RSpec.describe LinhaDoTempoHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  before do
    def helper.cliente_final? = false
    travel_to Time.zone.parse("2026-11-04 10:00")
  end

  def barra(grupo, fim: nil, dias_de_atraso: nil, pronta: false, inicio: Time.current, comecou_antes: false, sem_previsao: nil)
    instance_double(BarraNoTempo, grupo: grupo, fim: fim, dias_de_atraso: dias_de_atraso, pronta?: pronta, inicio: inicio, comecou_antes?: comecou_antes, sem_previsao: sem_previsao)
  end

  it "ends a bar on its previsão, its delay, the delivery, or why it has none" do
    sexta = Time.zone.parse("2026-11-13 15:00")
    falta = FilaDeProducao::Previsao.new(vezes: [ FilaDeProducao::Vez.new(motivo: "previsão quando Oxford entrar", trechos: []) ])
    rotulos = [ barra("em_producao", fim: sexta, dias_de_atraso: 2), barra("em_producao", fim: sexta, dias_de_atraso: 1), barra("em_producao", pronta: true),
                barra("entregues", fim: Time.zone.parse("2026-11-03 12:00")), barra("pendentes", fim: sexta), barra("sem_previsao", sem_previsao: falta) ].map { |b| helper.rotulo_da_barra(b) }
    expect(rotulos).to eq([ "sex 13/11 · atrasa 2 dias", "sex 13/11 · atrasa 1 dia", "pronto p/ entregar", "entregue 03/11", "se confirmar agora: sex 13/11", "previsão quando Oxford entrar" ])
    expect(helper.comeco_da_barra(barra("em_producao", inicio: Time.zone.parse("2026-10-30 09:00"), comecou_antes: true))).to eq("‹ começou sex 30/10")
  end

  it "says a day's load, and in its tip what today counts" do
    celulas = %i[passado sem_turno parada encerrado livre cheio].map { |estado| LinhaDoTempo::CelulaDaCarga.new(data: Date.current, estado: estado) }
    expect(celulas.map { |c| helper.texto_da_carga(c) }).to eq([ "·", "", "parada", "encerrado", "livre", "cheio" ])
    hoje = LinhaDoTempo::CelulaDaCarga.new(data: Date.current, estado: :ok, percentual: 64)
    expect([ helper.texto_da_carga(hoje), helper.dica_da_carga("Corte", hoje) ]).to eq([ "64%", "Corte · qua 04/11 · 64% das horas de turno que restam hoje" ])
  end

  it "marks a column of the faixa's timeline: now, past the deadline, already over" do
    coluna = TempoDoPedido::Coluna.new(agora: true, depois_do_prazo: false, passada: false)
    expect(helper.classes_da_coluna_do_tempo(coluna)).to eq(" painel-tdp-col--agora")
    expect(helper.classes_da_coluna_do_tempo(TempoDoPedido::Coluna.new(depois_do_prazo: true, passada: true))).to eq(" painel-tdp-col--prazo painel-tdp-col--passada")
  end

  it "builds the window's address, the default order left out" do
    expect(helper.painel_no_tempo(de: Date.new(2026, 11, 2), ordem: "chegada")).to eq("/painel?de=2026-11-02&visao=tempo")
    expect(helper.painel_no_tempo(de: Date.new(2026, 11, 2), ordem: "prazo")).to eq("/painel?de=2026-11-02&ordem=prazo&visao=tempo")
  end
end
