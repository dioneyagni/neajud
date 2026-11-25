require "rails_helper"

# Painel 2/4a (decided 05/11/2026, Q8a): a day or turno off, for the whole
# factory or one stage.
RSpec.describe ExcecaoCalendario do
  let(:tarde) { Turno.create!(nome: "Tarde", inicio: "14:00", fim: "22:00", dias: (1..5).to_a) }
  let(:quarta) { Date.new(2026, 11, 4) }

  def ocorrencia(turno, data = quarta)
    CalendarioDeProducao::Ocorrencia.new(turno: turno, data: data, inicio: data.in_time_zone, fim: data.in_time_zone + 8.hours)
  end

  def para?(excecao, ocorrencia, etapa = nil, maquina_id: nil) = excecao.parada_ate(ocorrencia, etapa, maquina_id: maquina_id).present?

  it "stops the whole factory, or only its stage, on its day" do
    fabrica = described_class.new(data: quarta, nome: "Recesso")
    calandra = described_class.new(data: quarta, nome: "Calandra parada", etapa: "calandra")
    fabrica.valid? && calandra.valid?
    expect([ para?(fabrica, ocorrencia(tarde), "corte"), para?(calandra, ocorrencia(tarde), "calandra"), para?(calandra, ocorrencia(tarde), "corte") ]).to eq([ true, true, false ])
    expect(para?(fabrica, ocorrencia(tarde, quarta + 1), "corte")).to be(false)
  end

  it "stops only its turno when it names one" do
    manha = Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: (1..5).to_a)
    excecao = described_class.new(data: quarta, nome: "Reunião", turno: tarde)
    excecao.valid?
    expect([ para?(excecao, ocorrencia(tarde)), para?(excecao, ocorrencia(manha)) ]).to eq([ true, false ])
    expect(excecao.abrangencia).to eq("toda a fábrica · Tarde")
  end

  it "refuses a stage that doesn't exist" do
    expect(described_class.new(data: quarta, nome: "X", etapa: "pintura").tap(&:valid?).errors[:etapa].first).to include('"pintura" is not a production stage')
  end

  it "keeps one national holiday per day" do
    described_class.create!(data: Date.new(2026, 11, 20), nome: "Consciência Negra", origem: "feriado")
    expect(described_class.new(data: Date.new(2026, 11, 20), nome: "Outra", origem: "feriado").valid?).to be(false)
    expect(described_class.new(data: Date.new(2026, 11, 20), nome: "Calandra parada", etapa: "calandra").valid?).to be(true)
  end

  # Máquinas 3/5a (decided 24/11/2026).
  describe "a stop of machines, over days" do
    def maquina(nome, **velocidades)
      Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
    end

    let(:calandra_2) { maquina("Calandra 2", calandra: 40, dublagem: 30) }
    let(:calandra_3) { maquina("Calandra 3", calandra: 40) }

    def com(*maquinas, **atributos)
      described_class.new(nome: "Manutenção", data: quarta, etapa: "calandra", **atributos).tap do |excecao|
        maquinas.each { |m| excecao.paradas_das_maquinas.build(maquina: m) }
      end
    end

    it "runs from its first day to its last, ending the day it starts when none is given (Q6a)" do
      excecao = com(calandra_2, data_fim: quarta + 2).tap(&:save!)
      expect((0..3).map { |dia| para?(excecao, ocorrencia(tarde, quarta + dia), maquina_id: calandra_2.id) }).to eq([ true, true, true, false ])
      expect(com(calandra_2).tap(&:save!).data_fim).to eq(quarta)
      expect(com(calandra_2, data_fim: quarta - 1).tap(&:valid?).errors[:data_fim].first).to include("before the start")
    end

    it "stops only its machines, each whole — in the other stages it does too (Q1a)" do
      excecao = com(calandra_2).tap(&:save!)
      expect([ para?(excecao, ocorrencia(tarde), "calandra", maquina_id: calandra_2.id), para?(excecao, ocorrencia(tarde), "dublagem", maquina_id: calandra_2.id),
               para?(excecao, ocorrencia(tarde), "calandra", maquina_id: calandra_3.id), para?(excecao, ocorrencia(tarde), "calandra") ]).to eq([ true, true, false, false ])
      expect([ excecao.abrangencia, excecao.tambem_para ]).to eq([ "Calandra › Calandra 2 · dia inteiro", [ "Dublagem" ] ])
      calandra_3
      expect(described_class.new(nome: "Limpeza", data: quarta, etapa: "calandra").abrangencia).to eq("Calandra › todas as máquinas · dia inteiro")
    end

    it "refuses a machine that doesn't do its stage, or machines with no stage" do
      epson = maquina("Epson", impressao_papel: 100)
      expect(com(epson).tap(&:valid?).errors[:maquinas].first).to eq("Epson don't do the Calandra")
      expect(com(calandra_2, etapa: nil).tap(&:valid?).errors[:maquinas].first).to include("need a stage")
    end

    it "stops until it came back to work, then lets the turno go on (Q7a)" do
      excecao = com(calandra_2).tap(&:save!)
      turno = ocorrencia(tarde)
      excecao.voltou_em = turno.inicio + 3.hours
      expect(excecao.parada_ate(turno, maquina_id: calandra_2.id)).to eq(turno.inicio + 3.hours)
      excecao.voltou_em = turno.inicio - 1.minute
      expect(excecao.parada_ate(turno, maquina_id: calandra_2.id)).to be_nil
      expect([ excecao.encerrada?(quarta), com(calandra_2).encerrada?(quarta), com(calandra_2).encerrada?(quarta + 1) ]).to eq([ true, false, true ])
    end

    it "lists in a year the stops touching it" do
      recesso = described_class.create!(nome: "Recesso", data: Date.new(2026, 12, 28), data_fim: Date.new(2027, 1, 4))
      expect([ described_class.do_ano(2026).to_a, described_class.do_ano(2027).to_a, described_class.do_ano(2025).to_a ]).to eq([ [ recesso ], [ recesso ], [] ])
    end
  end
end
