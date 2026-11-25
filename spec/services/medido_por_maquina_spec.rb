require "rails_helper"
require_relative "../support/producao_tecido"

# Máquinas 4/5b (decided 24–25/11/2026): each machine × trabalho measured
# from the baixas that say it (Q3a), its stages together; a machine doing
# two trabalhos in one turno splits the turno's hours by the time each took
# at its informada (Q1a). What a machine uses: fixada > its own measure >
# the stage's split by speed > its informada (Q4a: the fix is each
# machine's). 8 h turnos every day; the baixas' measure is their load (the
# Impressões count meters).
RSpec.describe "Medido por máquina" do
  let!(:manha) { Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: (0..6).to_a) }
  let(:agora) { Time.zone.parse("2026-11-20 18:00") }
  let(:calcado) { create(:pedido) }
  let(:dtf) { create(:pedido, tipo: "dtf") }
  let!(:epson_a) { maquina("Epson A", impressao_papel: 100, impressao_dtf: 50) }
  let!(:epson_b) { maquina("Epson B", impressao_papel: 300) }

  def maquina(nome, **velocidades)
    Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
  end

  # A baixa as it was given: the line checks are not what this measures.
  def baixa(dia, metros, em: nil, alvo: calcado, etapa: "impressao")
    BaixaProducao.new(uuid: SecureRandom.uuid, pedido: alvo, etapa: etapa, nivel: "pedido", linhas: [ "x" ], medida: metros, maquina: em,
                      created_at: Time.zone.parse("2026-11-#{dia} 10:00")).tap { |b| b.save!(validate: false) }
  end

  def medido
    RitmoMedido.new(CalendarioDeProducao.new, ate: agora)
  end

  describe RitmoMedido do
    it "measures each machine's trabalho from its own baixas, the stage from all of them" do
      5.times { |i| baixa(10 + i, 400, em: epson_a) }
      4.times { |i| baixa(10 + i, 800, em: epson_b) }
      baixa(15, 160)

      expect(medido.das_maquinas.transform_values { |m| [ m.valor, m.turnos ] }).to eq([ epson_a.id, "impressao_papel" ] => [ 50.0, 5 ])
      expect([ medido.turnos_da_maquina(epson_b.id, "impressao_papel"), medido.turnos_da_maquina(epson_b.id, "calandra") ]).to eq([ 4, 0 ])
      # Stage: 150, 150, 150, 150, 50 and 20 m/h — the median of six turnos.
      expect(medido.call[%w[calcado impressao]].then { |m| [ m.valor, m.turnos ] }).to eq([ 150.0, 6 ])
    end

    it "splits a turno between two trabalhos by the time each took at its informada (Q1a)" do
      # 400 m of paper at 100 m/h (4 h) and 200 m of DTF at 50 m/h (4 h): 4 h each.
      5.times do |i|
        baixa(10 + i, 400, em: epson_a)
        baixa(10 + i, 200, em: epson_a, alvo: dtf)
      end
      expect(medido.das_maquinas.transform_values(&:valor)).to eq([ epson_a.id, "impressao_papel" ] => 100.0, [ epson_a.id, "impressao_dtf" ] => 50.0)
    end

    it "leaves out a baixa on a machine that no longer does its trabalho" do
      5.times { |i| baixa(10 + i, 400, em: epson_a, alvo: dtf) }
      epson_a.trabalhos.find_by(trabalho: "impressao_dtf").destroy!
      expect(RitmoMedido.new(CalendarioDeProducao.new, ate: agora).das_maquinas).to eq({})
    end
  end

  describe RitmoDaMaquina do
    let(:ritmo) { RitmoProducao.da_fabrica[%w[calcado impressao]] }
    let(:trabalho) { epson_a.trabalho_de("impressao_papel") }
    let(:propria) { RitmoMedido::Medida.new(valor: 80.0, turnos: 5) }
    let(:da_etapa) { RitmoMedido::Medida.new(valor: 200.0, turnos: 8) }

    def em_uso(**medidas) = RitmoDaMaquina.em_uso(ritmo, trabalho, **{ propria: nil, da_etapa: nil }.merge(medidas)).then { |u| [ u.valor, u.origem ] }

    it "uses the fixed informada, else its own measure, else the stage's split by speed, else the informada" do
      # The stage's 200 m/h over 100 + 300 m/h: a quarter is the Epson A's.
      expect([ em_uso, em_uso(da_etapa: da_etapa), em_uso(propria: propria, da_etapa: da_etapa) ])
        .to eq([ [ 100.0, :informada ], [ 50.0, :da_etapa ], [ 80.0, :medida ] ])
      trabalho.fixar_informado = true
      expect(em_uso(propria: propria, da_etapa: da_etapa)).to eq([ 100.0, :fixada ])
    end

    it "gives a cutting machine its aproveitamento, all machine time unmeasured" do
      mesa = Maquina.new(nome: "Mesa 1").tap { |m| m.trabalhos.build(trabalho: "corte_calcado") }.tap(&:save!).trabalho_de("corte_calcado")
      corte = RitmoProducao.da_fabrica[%w[calcado corte]]
      expect(RitmoDaMaquina.em_uso(corte, mesa, propria: nil, da_etapa: nil).valor).to eq(1.0)
      expect(RitmoDaMaquina.em_uso(corte, mesa, propria: nil, da_etapa: RitmoMedido::Medida.new(valor: 0.6, turnos: 5)).valor).to eq(0.6)
    end
  end

  describe UsoDasMaquinas do
    it "says each machine's measure, the turnos missing and what each of its stages uses" do
      5.times { |i| baixa(10 + i, 400, em: epson_a) }
      2.times { |i| baixa(10 + i, 800, em: epson_b) }
      uso = UsoDasMaquinas.new(RitmoProducao.da_fabrica, medido)

      a = uso.do_trabalho(epson_a.trabalho_de("impressao_papel"))
      b = uso.do_trabalho(epson_b.trabalho_de("impressao_papel"))
      expect([ a.medida.valor, a.faltam, a.usos.map { |u| [ u.ritmo.tipo, u.em_uso.origem ] } ]).to eq([ 50.0, 0, [ [ "calcado", :medida ], [ "tecido", :medida ] ] ])
      # Its calçado stage is measured (5 turnos, 50 m/h at the median): three quarters are the Epson B's.
      expect([ b.medida, b.faltam, b.usos.map { |u| [ u.em_uso.valor, u.em_uso.origem ] } ]).to eq([ nil, 3, [ [ 37.5, :da_etapa ], [ 300.0, :informada ] ] ])
      expect(uso.medidas_da_etapa(RitmoProducao.da_fabrica[%w[calcado impressao]]).map(&:valor)).to eq([ 50.0 ])
    end
  end

  # The queue runs a piece at what its machine uses: a tecido pedido runs
  # 15,5 m on the Calandra, here on a 40 m/h machine measured at 10 m/h.
  describe FilaDeProducao do
    let(:sem_falta) { instance_double(AguardandoMaterial, avisos_do_pedido: [], do_pedido: []) }

    it "times a machine's piece at its own measure" do
      calandra = maquina("Calandra 2", calandra: 40)
      medidos = create(:pedido, tipo: "tecido")
      5.times { |i| baixa(10 + i, 80, em: calandra, alvo: medidos, etapa: "calandra") }
      pedido = pedido_tecido_confirmado

      vez = FilaDeProducao.call(agora: agora, aguardando: sem_falta).previsao(pedido).vezes.find { |v| v.etapa.chave == "calandra" }
      expect([ vez.maquina, vez.carga, vez.horas ]).to eq([ calandra, 15.5, 1.55 ])
    end
  end
end
