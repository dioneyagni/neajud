require "rails_helper"
require_relative "../support/producao_tecido"

# Painel 2/4c (Q5a): the faixa's timeline of one pedido — a lane per stage,
# a column per turno from now to its previsão, each stage's share of the
# turno; a day per column for a cliente final (Q4a). A tecido pedido here
# prints 15,5 m and then runs them on the Calandra.
RSpec.describe TempoDoPedido do
  let(:sem_falta) { instance_double(AguardandoMaterial, do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:pedido) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 1.hour, prazo_entrega: Date.new(2026, 11, 3)) } }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
  end

  def ritmos(impressao:, calandra: 31)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: impressao)
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: calandra) if calandra
  end

  def tempo(cliente_final: false, planos: {})
    pedido
    fila = FilaDeProducao.call(agora: quarta, aguardando: sem_falta)
    described_class.call(LinhaDoPainel.call(pedido.reload, aguardando: sem_falta, fila: fila), fila: fila, cliente_final: cliente_final, planos: planos)
  end

  # The Impressão's first plan: one turno, from inicio.
  def plano(inicio)
    PlanoDaEtapa.new(pedido: pedido, etapa: "impressao", setor: "impressao", fim: inicio + 4.hours, turno_nome: "Tarde", data: inicio.to_date,
                     trechos: [ { "inicio" => inicio.iso8601, "fim" => (inicio + 4.hours).iso8601 } ])
  end

  def raias(t)
    t.raias.map { |raia| [ raia.etapa.chave, raia.estado, raia.celulas ] }
  end

  it "fills a column per turno from now, each stage's share, the turnos past the deadline marked" do
    # 5 h of Impressão: the Manhã and an hour of the Tarde; the Calandra's half hour after.
    ritmos(impressao: 3.1)
    t = tempo

    expect(t.colunas.map { |c| [ c.nome, c.agora, c.depois_do_prazo ] }).to eq([ [ "Manhã", true, true ], [ "Tarde", false, true ] ])
    expect(raias(t)).to eq([ [ "impressao", :prevista, [ 1.0, 0.25 ] ], [ "calandra", :prevista, [ nil, 0.13 ] ] ])
    expect(t.restantes).to eq(0)
  end

  it "marks a stage done, and says why one has no previsão" do
    ritmos(impressao: 3.1, calandra: nil)
    expect(raias(tempo)).to eq([ [ "impressao", :prevista, [ 1.0, 0.25 ] ], [ "calandra", :sem_previsao, [] ] ])
    expect(tempo.raias.last.vez.motivo).to eq("Calandra (Tecido) sem ritmo")

    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: 31)
    RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
    expect(raias(tempo)).to eq([ [ "impressao", :feita, [] ], [ "calandra", :prevista, [ 0.13 ] ] ])
    # 3/4b2: a stage done has no plan drawn (nil broke the faixa's legend).
    expect(tempo.raias.map(&:planejadas)).to eq([ [], [] ])
  end

  it "draws no more than 24 turnos, saying how many more" do
    ritmos(impressao: 0.1)
    expect([ tempo.colunas.size, tempo.restantes ]).to eq([ 24, 15 ])
  end

  it "gives a cliente final a column per day" do
    ritmos(impressao: 3.1)
    t = tempo(cliente_final: true)
    expect([ t.colunas.map(&:nome), raias(t).first.last ]).to eq([ [ nil ], [ 0.56 ] ])
  end

  # Q8a: planned for Tuesday's Tarde, it now ends in Wednesday's.
  it "draws the first plan dashed from its turno already over, with an arrow to where it ends now" do
    ritmos(impressao: 3.1)
    t = tempo(planos: { "impressao" => plano(quarta - 19.hours) })

    expect(t.colunas.map { |c| [ c.data.day, c.nome, c.passada ] }).to eq([ [ 3, "Tarde", true ], [ 4, "Manhã", false ], [ 4, "Tarde", false ] ])
    impressao = t.raias.first
    expect([ impressao.celulas, impressao.planejadas ]).to eq([ [ nil, 1.0, 0.25 ], [ 1.0, nil, nil ] ])
    expect(impressao.seta.to_h).to eq(de: 0, para: 2, turnos: 2)
    expect(t.raias.last.seta).to be_nil
  end

  it "keeps the last 8 turnos over, the arrow counting them all" do
    ritmos(impressao: 3.1)
    t = tempo(planos: { "impressao" => plano(Time.zone.parse("2026-10-21 13:00")) })

    expect([ t.colunas.count(&:passada), t.colunas.size ]).to eq([ 8, 10 ])
    expect(t.raias.first.seta.to_h).to eq(de: 0, para: 9, turnos: 20)
  end

  it "has no plan, no arrow, no turno over for a cliente final" do
    ritmos(impressao: 3.1)
    t = tempo(cliente_final: true, planos: { "impressao" => plano(quarta - 19.hours) })
    expect([ t.colunas.size, t.raias.first.planejadas, t.raias.first.seta ]).to eq([ 1, [], nil ])
  end

  it "has none when nothing of it is in the queue (no rhythm)" do
    pedido
    expect(tempo).to be_nil
  end
end
