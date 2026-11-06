require "rails_helper"
require_relative "../support/producao_calcado"
require_relative "../support/producao_tecido"

# Painel 2/4b (decided 05–06/11/2026): a queue per sector in arrival order,
# each pedido by its tipo's rhythm, filling the turnos from now; a stage
# starts when the ones it waits for end. A tecido pedido here prints 15,5 m
# (12,5 + 3) and then runs them on the Calandra.
RSpec.describe FilaDeProducao do
  include ActiveSupport::Testing::TimeHelpers

  let(:sem_falta) { instance_double(AguardandoMaterial, do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
  end

  def ritmos(impressao: 15.5, calandra: 31)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: impressao)
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: calandra) if calandra
  end

  def tecido(confirmado_em)
    pedido_tecido_confirmado.tap { |pedido| pedido.update_columns(confirmado_em: confirmado_em) }
  end

  def fila(agora = quarta, aguardando: sem_falta)
    described_class.call(agora: agora, aguardando: aguardando)
  end

  def horarios(vez)
    vez.trechos.map { |trecho| "#{trecho.inicio.strftime("%a %H:%M")}–#{trecho.fim.strftime("%H:%M")}" }
  end

  def vez(fila, pedido, etapa)
    fila.previsao(pedido).vezes.find { |v| v.etapa.chave == etapa }
  end

  it "fills the turnos from now in arrival order, each stage after the one it waits for" do
    ritmos
    segundo = tecido(quarta - 30.minutes)
    primeiro = tecido(quarta - 1.hour)
    f = fila

    expect(f.do_setor("impressao").map { |v| [ v.pedido, v.posicao, horarios(v) ] })
      .to eq([ [ primeiro, 1, [ "Wed 08:00–09:00" ] ], [ segundo, 2, [ "Wed 09:00–10:00" ] ] ])
    # The Calandra is the Estamparia's column (LinhaDoPainel::COLUNA_DA_ETAPA).
    expect(f.do_setor("estamparia").map { |v| [ v.pedido, horarios(v), v.espera&.etapa&.chave ] })
      .to eq([ [ primeiro, [ "Wed 09:00–09:30" ], "impressao" ], [ segundo, [ "Wed 10:00–10:30" ], "impressao" ] ])
    expect([ f.previsao(primeiro).fim, f.previsao(segundo).fim ]).to eq([ quarta + 90.minutes, quarta + 150.minutes ])
    expect([ vez(f, primeiro, "impressao").carga, vez(f, primeiro, "impressao").horas ]).to eq([ 15.5, 1.0 ])
  end

  it "counts only what is left of the turno under way, and skips a day the stage stops" do
    ritmos
    pedido = tecido(quarta - 1.hour)
    ExcecaoCalendario.create!(data: quarta.to_date, nome: "Calandra parada", etapa: "calandra")
    f = fila(quarta + 3.5.hours)

    expect(horarios(vez(f, pedido, "impressao"))).to eq([ "Wed 11:30–12:00", "Wed 13:00–13:30" ])
    expect(horarios(vez(f, pedido, "calandra"))).to eq([ "Thu 08:00–08:30" ])
    expect(f.turnos_do_setor("impressao").map { |t| [ t.ocorrencia.turno.nome, t.ocupadas, t.livres ] }).to eq([ [ "Manhã", 0.5, 0.5 ], [ "Tarde", 0.5, 4.0 ] ])
  end

  it "starts a stage now when the one it waits for is done" do
    ritmos
    pedido = tecido(quarta - 1.hour)
    RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
    f = fila

    expect(f.previsao(pedido).vezes.map { |v| [ v.etapa.chave, horarios(v), v.espera ] }).to eq([ [ "calandra", [ "Wed 08:00–08:30" ], nil ] ])
  end

  # Q10a: a turno past midnight is the day it starts.
  it "runs a turno past midnight, of the day it starts" do
    Turno.destroy_all
    Turno.create!(nome: "Noite", inicio: "22:00", fim: "06:00", dias: [ 3 ])
    ritmos(impressao: 7.75, calandra: nil)
    pedido = tecido(quarta - 1.hour)
    trecho = vez(fila(Time.zone.parse("2026-11-04 23:00")), pedido, "impressao").trechos.sole

    expect([ trecho.ocorrencia.data, trecho.fim ]).to eq([ quarta.to_date, Time.zone.parse("2026-11-05 01:00") ])
  end

  # Q1c, decided 06/11/2026: a missing material holds only the stage that
  # takes it — without fabric the Impressão runs and the Calandra waits.
  describe "a missing material" do
    let(:pedido) { tecido(quarta - 1.hour) }

    def faltando(material)
      instance_double(AguardandoMaterial, do_pedido: [ AguardandoMaterial::Falta.new(pedido_id: pedido.id, materia_prima: material, metros: 3) ])
    end

    before { ritmos }

    it "of fabric holds the Calandra, which takes no place in the queue" do
      oxford = pedido.itens_pedido.first.materia_prima
      f = fila(aguardando: faltando(oxford))

      expect(horarios(vez(f, pedido, "impressao"))).to eq([ "Wed 08:00–09:00" ])
      calandra = vez(f, pedido, "calandra")
      expect([ calandra.fim, calandra.falta, calandra.motivo, calandra.posicao ]).to eq([ nil, true, "previsão quando #{oxford.nome_completo} entrar", nil ])
      expect([ f.previsao(pedido).fim, f.previsao(pedido).sem_previsao ]).to eq([ nil, calandra.motivo ])
    end

    it "of paper holds the Impressão and the Calandra waiting for it" do
      papel = criar_tecido(largura: "1.60")
      pedido.update_columns(material_impressao_id: papel.id)
      f = fila(aguardando: faltando(papel))

      expect(f.previsao(pedido).vezes.map { |v| [ v.etapa.chave, v.fim, v.motivo ] })
        .to eq([ [ "impressao", nil, "previsão quando #{papel.nome_completo} entrar" ], [ "calandra", nil, "previsão quando #{papel.nome_completo} entrar" ] ])
      expect(f.do_setor("impressao").map(&:posicao)).to eq([ nil ])
    end
  end

  # Q2a: no rhythm, no previsão from that stage on.
  it "leaves a stage without rhythm, and what waits for it, without previsão" do
    ritmos(calandra: nil)
    pedido = tecido(quarta - 1.hour)
    f = fila

    expect(f.previsao(pedido).vezes.map { |v| [ v.etapa.chave, v.fim.present?, v.motivo ] })
      .to eq([ [ "impressao", true, nil ], [ "calandra", false, "Calandra (Tecido) sem ritmo" ] ])
  end

  it "has no previsão past 90 days ahead, nor without turnos" do
    ritmos(impressao: 0.001)
    pedido = tecido(quarta - 1.hour)
    expect(vez(fila, pedido, "impressao").motivo).to eq("a fila passa de 90 dias")
    Turno.destroy_all
    expect(vez(fila, pedido, "impressao").motivo).to eq("sem turnos cadastrados")
  end

  # Q1c: a draft or a sent pedido is placed after everyone, moving no one.
  it "places a draft after the whole queue, pushing no one, and none with pendências" do
    ritmos
    confirmado = tecido(quarta - 1.hour)
    rascunho = pedido_tecido_confirmado.tap { |p| p.update_columns(status: "rascunho") }
    f = fila

    previsao = f.se_confirmar(rascunho)
    expect([ previsao.se_confirmar, horarios(previsao.vezes.first), previsao.fim ]).to eq([ true, [ "Wed 09:00–10:00" ], quarta + 150.minutes ])
    expect(f.se_confirmar(rascunho).fim).to eq(previsao.fim)
    expect([ f.previsao(rascunho), f.do_setor("impressao").map(&:pedido) ]).to eq([ nil, [ confirmado ] ])
    expect(f.se_confirmar(rascunho, pendencias: true).sem_previsao).to eq("resolva as pendências para ter a previsão")
  end

  # Painel 2/4a2 A6b: the machine changes material between pedidos in a row.
  it "adds the cutting machine's material change from the pedido before" do
    primeiro = pedido_calcado_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 2.hours) }
    segundo = pedido_calcado_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 1.hour) }
    terceiro = pedido_calcado_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 30.minutes) }
    terceiro.itens_pedido.first.update_columns(materia_prima_id: criar_tecido(largura: "1.40").id)
    cargas = fila.do_setor("corte").map(&:carga)

    expect(cargas[1]).to eq(cargas[0])
    expect(cargas[2] - cargas[0]).to be_within(0.001).of(10 / 60.0)
  end
end
