require "rails_helper"

# Painel 2/4b: the previsão, the folga chip (the Fila A mockup) and the
# queue's moments; a cliente final sees days, never the material's name.
RSpec.describe FilaDeProducaoHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  let(:etapa) { EtapasProducao.etapa("calcado", "corte") }

  before do
    def helper.cliente_final? = @cliente_final || false
    travel_to Time.zone.parse("2026-11-04 10:00")
  end

  def como_cliente_final
    helper.instance_variable_set(:@cliente_final, true)
  end

  it "colors the folga: late in red, on the day or 1 day in orange, more in green" do
    selos = [ -2, 0, 1, 3 ].map { |folga| Nokogiri::HTML.fragment(helper.selo_da_folga(folga)).at("span") }
    expect(selos.map { |selo| [ selo["class"], selo.text ] })
      .to eq([ [ "painel-folga painel-folga--atrasa", "atrasa 2 dias" ], [ "painel-folga painel-folga--justa", "vence no dia" ],
               [ "painel-folga painel-folga--justa", "folga 1 dia" ], [ "painel-folga painel-folga--ok", "folga 3 dias" ] ])
    expect(helper.selo_da_folga(nil)).to be_nil
  end

  it "says a moment by today, tomorrow or the weekday — by day only for a cliente final" do
    expect([ "2026-11-04 15:30", "2026-11-05 09:00", "2026-11-12 08:00" ].map { |m| helper.momento_da_fila(Time.zone.parse(m)) })
      .to eq([ "hoje 15:30", "amanhã 09:00", "qui 12/11 08:00" ])
    como_cliente_final
    expect(helper.momento_da_fila(Time.zone.parse("2026-11-12 08:00"))).to eq("qui 12/11")
  end

  it "says the previsão, a draft's if confirmed now, or why there is none" do
    vez = FilaDeProducao::Vez.new(etapa: etapa, fim: Time.zone.parse("2026-11-05 09:00"), trechos: [])
    sem = FilaDeProducao::Vez.new(etapa: etapa, motivo: "previsão quando Oxford Preto entrar", falta: true, trechos: [])
    expect(helper.texto_da_previsao(FilaDeProducao::Previsao.new(vezes: [ vez ], se_confirmar: true))).to eq("se confirmar agora: amanhã 09:00")
    expect(helper.texto_da_previsao(FilaDeProducao::Previsao.new(vezes: []))).to eq("pronto p/ entregar")
    expect(helper.texto_da_previsao(FilaDeProducao::Previsao.new(vezes: [ vez, sem ]))).to eq("previsão quando Oxford Preto entrar")
    como_cliente_final
    expect(helper.texto_da_previsao(FilaDeProducao::Previsao.new(vezes: [ sem ]))).to eq("previsão quando o material entrar")
  end

  it "says a stage's period and load, and the next turno change" do
    vez = FilaDeProducao::Vez.new(etapa: etapa, inicio: Time.zone.parse("2026-11-04 10:00"), fim: Time.zone.parse("2026-11-04 11:30"), carga: 1.42, trechos: [])
    expect([ helper.periodo_da_vez(vez), helper.carga_da_vez(vez), helper.horas_da_fila(0.5), helper.horas_da_fila(2.25) ])
      .to eq([ "hoje 10:00 → 11:30", "1,4 h de máquina", "30 min", "2,3 h" ])
    turno = Turno.new(nome: "Manhã", inicio: "08:00", fim: "12:00")
    ocorrencia = CalendarioDeProducao::Ocorrencia.new(turno: turno, data: Date.current, inicio: Time.zone.parse("2026-11-04 08:00"), fim: Time.zone.parse("2026-11-04 12:00"))
    fila = instance_double(FilaDeProducao, agora: Time.current, ocorrencias: [ ocorrencia ])
    expect(helper.proxima_virada(fila)).to eq((Time.zone.parse("2026-11-04 12:00").to_f * 1000).round)
  end
end
