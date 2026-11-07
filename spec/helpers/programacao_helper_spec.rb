require "rails_helper"
require_relative "../support/fake_programado_na_fila"

# Painel 3/4a: the impact window's title and each line of a pedido's
# "Histórico da programação". Painel 3/4b: a virada in it, the "veio de ·
# adiada" mark and a turno's load over 100%.
RSpec.describe ProgramacaoHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  let(:pessoa) { create(:user, nome: "Dione") }
  let(:movido) { create(:pedido, tipo: "tecido") }
  let(:empurrado) { create(:pedido, tipo: "tecido") }

  before do
    def helper.cliente_final? = false
    travel_to Time.zone.parse("2026-11-05 14:20")
  end

  def movimento(**dados)
    MovimentoDaFila.create!(pedido: movido, user: pessoa, etapa: "impressao", setor: "impressao", de: 3, para: 1, ordem_em: 1.hour.ago, **dados)
  end

  it "says a move to its pedido, to the ones it pushed, and a move back" do
    m = movimento(motivo: "cliente pediu urgência", empurrados: [ { "pedido_id" => empurrado.id, "de" => "2026-11-12T15:30:00-03:00", "para" => "2026-11-13T09:00:00-03:00" } ])
    numero = "##{movido.uuid.first(8)}"

    expect(helper.linha_do_historico(m, movido)).to eq("05/11 14:20 · Dione passou o #{numero} à frente na Impressão (3º → 1º) · cliente pediu urgência · passou à frente de 2 pedidos")
    expect(helper.linha_do_historico(m, empurrado)).to eq("05/11 14:20 · Dione passou o #{numero} à frente na Impressão (3º → 1º) · cliente pediu urgência · este pedido: qui 12/11 15:30 → sex 13/11 09:00")
    expect(helper.linha_do_historico(movimento(de: 1, para: 3, ordem_em: nil), movido)).to eq("05/11 14:20 · Dione voltou o #{numero} à ordem de chegada na Impressão")
    expect(helper.previsao_do_impacto(nil)).to eq("sem previsão")
  end

  # 3/4b2 (Q9a): "quem cruzou", the other pedido's number a link.
  it "says who crossed a pedido and why, by a move or a virada" do
    m = movimento(motivo: "urgente", empurrados: [ { "pedido_id" => empurrado.id, "de" => Time.current.iso8601, "para" => 1.day.from_now.iso8601 } ])
    virada = ViradaDoPedido.create!(pedido: empurrado, turno_nome: "Tarde", data: Date.current, turno_fim: 2.hours.from_now, de: Time.current,
                                    nao_terminaram: [ { "pedido" => movido.uuid, "etapa" => "Impressão", "veio_de" => "Manhã", "a_frente" => true } ])
    @cruzamentos = CruzamentosDoPedido.call([ movido, empurrado ], historicos: { movido.id => [ m ], empurrado.id => [ m, virada ] },
                                            viradas: ViradaDoPedido.all, visiveis: Pedido.all)
    numero = "##{movido.uuid.first(8)}"

    expect(helper.cruzamentos_da_faixa(empurrado).map { |c| Nokogiri::HTML(helper.linha_do_cruzamento(c)).text })
      .to eq([ "#{numero} empurrou este pedido · 05/11 · Dione passou o #{numero} à frente na Impressão (3º → 1º) · urgente",
               "#{numero} empurrou este pedido · 05/11 · não terminou a Impressão na Manhã" ])
    outro = "##{empurrado.uuid.first(8)}"
    expect(helper.cruzamentos_da_faixa(movido).map { |c| Nokogiri::HTML(helper.linha_do_cruzamento(c)).text })
      .to eq([ "este pedido empurrou o #{outro} · 05/11 · Dione passou o #{numero} à frente na Impressão (3º → 1º) · urgente",
               "este pedido empurrou o #{outro} · 05/11 · a Impressão deste não terminou na Manhã" ])
    expect(helper.linha_do_cruzamento(helper.cruzamentos_da_faixa(movido).first)).to include("href=\"/pedidos/#{empurrado.uuid}/resumo\"")
  end

  it "gives the faixa each stage's first plan, none when the Painel read none" do
    expect(helper.planos_da_faixa(movido)).to eq({})
    plano = PlanoDaEtapa.create!(pedido: movido, etapa: "impressao", setor: "impressao", turno_nome: "Manhã", data: Date.current)
    @planos = { movido.id => [ plano ] }
    expect(helper.planos_da_faixa(movido)).to eq("impressao" => plano)
  end

  it "titles the window by the move" do
    vez = FilaDeProducao::Vez.new(pedido: movido, etapa: EtapasProducao.etapa("tecido", "impressao"))
    titulos = [ [ :posicao, 3, 1 ], [ :chegada, 1, 3 ] ].map { |tipo, de, para| helper.titulo_do_impacto(ImpactoDoMovimento::Impacto.new(tipo: tipo, vez: vez, de: de, para: para, setor: "impressao")) }
    titulos << helper.titulo_do_impacto(ImpactoDoMovimento::Impacto.new(tipo: :setor, setor: "impressao", movimentos: [ 1, 2 ]))
    expect(titulos).to eq([ "##{movido.uuid.first(8)} · Impressão: 3º → 1º", "##{movido.uuid.first(8)} · Impressão: voltar à ordem de chegada (1º → 3º)",
                            "Fila da Impressão: voltar tudo à ordem de chegada (2 movidas)" ])
  end

  def virada(**dados)
    ViradaDoPedido.create!(pedido: empurrado, turno_nome: "Tarde", data: Date.current, turno_fim: 3.hours.from_now, de: Time.zone.parse("2026-11-12 15:30"),
                           para: Time.zone.parse("2026-11-13 09:00"), **dados)
  end

  it "says a virada: the stages that didn't end, this pedido's previsão, whether it came to be late" do
    nao = [ { "pedido" => "c210aa12", "etapa" => "Impressão", "veio_de" => "Manhã" }, { "pedido" => "a4f1bb00", "etapa" => "Corte", "veio_de" => "Manhã" } ]

    expect(helper.linha_do_historico(virada(nao_terminaram: nao, passou_a_atrasar: true), empurrado))
      .to eq("05/11 14:20 · virada para a Tarde · não terminaram na Manhã: Impressão do #c210aa12, Corte do #a4f1bb00 · este pedido: qui 12/11 15:30 → sex 13/11 09:00 · passou a atrasar")
    expect(helper.linha_da_virada(virada(para: nil))).to eq("05/11 14:20 · virada para a Tarde · a fila mudou desde o turno anterior · este pedido: qui 12/11 15:30 → sem previsão")
  end

  it "puts a pedido's moves and viradas in one history, by time" do
    m = movimento(empurrados: [ { "pedido_id" => empurrado.id, "de" => 1.day.from_now.iso8601, "para" => 2.days.from_now.iso8601 } ])
    travel 1.minute
    v = virada
    # The team's view: every row.
    def helper.visiveis(modelo) = modelo.all

    expect(helper.historico_da_programacao(empurrado)).to eq([ m, v ])
  end

  it "says where a stage came from, and how many turnos it was put off" do
    adiamento = ->(dia, turnos) { ProgramadoNaFila::Adiamento.new(veio_de: "Manhã", veio_em: dia, turnos: turnos) }

    expect(helper.texto_do_adiamento(adiamento.(Date.current, 1))).to eq("veio de hoje · Manhã")
    expect(helper.texto_do_adiamento(adiamento.(Date.current - 1, 3))).to eq("veio de ontem · Manhã · adiada 3 turnos")
    expect(helper.texto_do_adiamento(adiamento.(Date.new(2026, 11, 2), 2))).to eq("veio de seg 02/11 · Manhã · adiada 2 turnos")
    expect(helper.texto_do_adiamento(nil)).to be_nil
  end

  describe "a turno's load in its sector's queue" do
    let(:ocorrencia) { CalendarioDeProducao::Ocorrencia.new(turno: Turno.new(nome: "Manhã"), data: Date.current) }

    def carga(ocupadas, livres, programado)
      helper.instance_variable_set(:@programado, programado)
      helper.carga_do_turno(FilaDeProducao::TurnoDaFila.new(ocorrencia: ocorrencia, pecas: [ [ nil, Struct.new(:horas).new(ocupadas) ] ], livres: livres), "impressao").to_h
    end

    it "is the queue's, or what its photo programmed still to do when more — past the hours left, over 100%" do
      expect(carga(2.0, 4.0, nil)).to eq(ocupadas: 2.0, percentual: 50, estourou: false)
      expect(carga(2.0, 4.0, FakeProgramadoNaFila.new(turno: { [ "impressao", "Manhã" ] => 3.0 }))).to eq(ocupadas: 3.0, percentual: 75, estourou: false)
      expect(carga(4.0, 4.0, FakeProgramadoNaFila.new(turno: { [ "impressao", "Manhã" ] => 5.2 }))).to eq(ocupadas: 5.2, percentual: 130, estourou: true)
    end
  end
end
