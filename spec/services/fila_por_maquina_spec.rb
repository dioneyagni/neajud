require "rails_helper"
require_relative "../support/producao_calcado"
require_relative "../support/producao_tecido"

# Máquinas 2/5a (decided 20–21/11/2026): the queue per machine. A piece goes
# on the machine that ends it first (Q3a), at that machine's speed; a
# machine is one agenda whatever trabalhos it does (Q1a); no strict order —
# the one that may start first goes, its arrival breaking ties (Q2a). A
# tecido pedido here prints 15,5 m (12,5 + 3) and runs them on the Calandra.
RSpec.describe FilaDeProducao do
  let(:sem_falta) { instance_double(AguardandoMaterial, avisos_do_pedido: [], do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
  end

  def ritmos(impressao: 15.5, calandra: 31)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: impressao) if impressao
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: calandra) if calandra
  end

  # Usage: maquina("Calandra 2", calandra: 40, dublagem: 30)
  def maquina(nome, **velocidades)
    Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
  end

  def tecido(confirmado_em)
    pedido_tecido_confirmado.tap { |pedido| pedido.update_columns(confirmado_em: confirmado_em) }
  end

  def fila(agora = quarta)
    described_class.call(agora: agora, aguardando: sem_falta)
  end

  def horarios(vez)
    vez.trechos.map { |trecho| "#{trecho.inicio.strftime("%a %H:%M")}–#{trecho.fim.strftime("%H:%M")}" }
  end

  def vez(fila, pedido, etapa)
    fila.previsao(pedido).vezes.find { |v| v.etapa.chave == etapa }
  end

  def baixa_da_impressao(pedido)
    RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
  end

  describe "the machine that ends it first (Q3a)" do
    it "runs two pedidos at once on two machines, each at its own speed" do
      ritmos(impressao: 31, calandra: nil)
      c2 = maquina("Calandra 2", calandra: 15.5)
      c3 = maquina("Calandra 3", calandra: 15.5)
      primeiro = tecido(quarta - 1.hour)
      segundo = tecido(quarta - 30.minutes)

      # Printed 08:00–08:30 and 08:30–09:00; the Calandra 2 is still busy at 09:00.
      expect(fila.do_setor("estamparia").map { |v| [ v.pedido, v.maquina, v.horas, horarios(v) ] })
        .to eq([ [ primeiro, c2, 1.0, [ "Wed 08:30–09:30" ] ], [ segundo, c3, 1.0, [ "Wed 09:00–10:00" ] ] ])
    end

    it "picks the faster machine when both are free, and the first registered on a tie" do
      ritmos(calandra: nil)
      lenta = maquina("Calandra 2", calandra: 15.5)
      rapida = maquina("Calandra 3", calandra: 31)
      pedido = tecido(quarta - 1.hour)
      expect(vez(fila, pedido, "calandra").then { |v| [ v.maquina, v.horas, v.recurso ] }).to eq([ rapida, 0.5, "maquina:#{rapida.id}" ])

      rapida.trabalho_de("calandra").update!(por_hora: 15.5)
      expect(vez(fila, pedido, "calandra").maquina).to eq(lenta)
    end

    # Found on the dev data (21/11/2026): the third pedido, placed after the
    # second, ends first on the slower machine free now — it starts first.
    it "numbers a sector's places by when they start" do
      rapida = maquina("Epson R", impressao_papel: 310)
      lenta = maquina("Epson L", impressao_papel: 110)
      um, dois, tres = [ 3, 2, 1 ].map { |horas| tecido(quarta - horas.hours) }

      expect(fila.do_setor("impressao").map { |v| [ v.pedido, v.posicao, v.maquina, v.inicio.strftime("%H:%M") ] })
        .to eq([ [ um, 1, rapida, "08:00" ], [ tres, 2, lenta, "08:00" ], [ dois, 3, rapida, "08:03" ] ])
    end

    it "leaves a machine in the trash out" do
      ritmos(calandra: nil)
      lenta = maquina("Calandra 2", calandra: 15.5)
      maquina("Calandra 3", calandra: 31).excluir!(changed_by: "127.0.0.1")
      pedido = tecido(quarta - 1.hour)
      expect(vez(fila, pedido, "calandra").maquina).to eq(lenta)
    end
  end

  # Q2a (21/11/2026, "ordem estrita me incomoda"), with or without machines.
  describe "no strict order (Q2a)" do
    before { ritmos(calandra: 15.5) }

    it "runs a later pedido that is ready while an earlier one waits for its Impressão" do
      antigo = tecido(quarta - 2.hours)
      pronto = tecido(quarta - 1.hour).tap { |pedido| baixa_da_impressao(pedido) }
      f = fila

      expect(f.do_setor("estamparia").map { |v| [ v.pedido, v.posicao, horarios(v), v.maquina ] })
        .to eq([ [ pronto, 1, [ "Wed 08:00–09:00" ], nil ], [ antigo, 2, [ "Wed 09:00–10:00" ], nil ] ])
    end

    it "puts the one that waited in its arrival place once ready, ahead of the ones after it" do
      antigo = tecido(quarta - 3.hours)
      meio = tecido(quarta - 2.hours).tap { |pedido| baixa_da_impressao(pedido) }
      novo = tecido(quarta - 1.hour).tap { |pedido| baixa_da_impressao(pedido) }

      # At 09:00 the old one's Impressão ends and the new one is ready too: the old goes.
      expect(fila.do_setor("estamparia").map { |v| [ v.pedido, horarios(v) ] })
        .to eq([ [ meio, [ "Wed 08:00–09:00" ] ], [ antigo, [ "Wed 09:00–10:00" ] ], [ novo, [ "Wed 10:00–11:00" ] ] ])
    end
  end

  # Q1a: one agenda per machine, whatever it does — its trabalhos' queues
  # share its time by arrival, and each sector sees the other's pieces.
  describe "a machine doing two sectors' trabalhos (Q1a)" do
    let!(:combo) { maquina("Combo", impressao_papel: 15.5, calandra: 31) }
    let!(:primeiro) { tecido(quarta - 2.hours) }
    let!(:segundo) { tecido(quarta - 1.hour) }

    it "never runs two pieces at once, the first arrival first on a tie" do
      f = fila
      expect([ primeiro, segundo ].map { |p| [ horarios(vez(f, p, "impressao")), horarios(vez(f, p, "calandra")) ] })
        .to eq([ [ [ "Wed 08:00–09:00" ], [ "Wed 09:00–09:30" ] ], [ [ "Wed 09:30–10:30" ], [ "Wed 10:30–11:00" ] ] ])
    end

    it "counts the other sector's pieces on it as taken, in its lane" do
      f = fila
      turno = f.turnos_do_setor("estamparia").first

      expect(f.de_outros_setores("estamparia").map { |v| [ v.pedido, v.etapa.chave ] }).to eq([ [ primeiro, "impressao" ], [ segundo, "impressao" ] ])
      expect([ turno.ocupadas, turno.livres, turno.com_maquinas? ]).to eq([ 3.0, 4.0, true ])
      expect(turno.raias.map { |raia| [ raia.recurso.maquina, raia.ocupadas, raia.livres ] }).to eq([ [ combo, 3.0, 4.0 ] ])
    end
  end

  it "gives a sector its machines' hours summed, and one lane with none" do
    ritmos(calandra: nil)
    maquina("Calandra 2", calandra: 15.5)
    maquina("Calandra 3", calandra: 15.5)
    tecido(quarta - 1.hour)
    f = fila
    turno = f.turnos_do_setor("estamparia").first

    expect([ turno.livres, f.horas_do_setor(turno.ocorrencia, "estamparia"), turno.raias.size ]).to eq([ 8.0, 8.0, 2 ])
    expect([ f.turnos_do_setor("impressao").first.livres, f.turnos_do_setor("impressao").first.com_maquinas? ]).to eq([ 4.0, false ])
  end

  # Q8a: each cutting machine by its parameters, its troca from the material it ended on.
  describe "the Corte do calçado per machine (Q8a)" do
    def mesa(nome, **parametros)
      Maquina.new(nome: nome).tap { |m| m.trabalhos.build(trabalho: "corte_calcado", **parametros) }.tap(&:save!)
    end

    it "cuts on the machine that ends first, at its own parameters" do
      mesa("Mesa 1")
      rapida = mesa("Mesa 2", velocidade_mm_s: 150, pinca_s: 1, preparo_min: 2, recolhimento_pecas_min: 20)
      pedido = pedido_calcado_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 1.hour) }
      corte = vez(fila, pedido, "corte")
      expect(corte.maquina).to eq(rapida)

      rapida.excluir!(changed_by: "127.0.0.1")
      expect(vez(fila, pedido, "corte").carga).to be > corte.carga
    end

    it "counts no troca between pedidos cut on different machines" do
      um, dois = mesa("Mesa 1"), mesa("Mesa 2")
      primeiro = pedido_calcado_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 2.hours) }
      segundo = pedido_calcado_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 1.hour) }
      segundo.itens_pedido.first.update_columns(materia_prima_id: criar_tecido(largura: "1.40").id)
      cortes = fila.do_setor("corte")

      expect(cortes.map(&:maquina)).to eq([ um, dois ])
      expect(cortes[1].carga).to eq(cortes[0].carga)
    end
  end
end
