require "rails_helper"
require_relative "../support/producao_tecido"

# Máquinas 2/5b (decided 21/11/2026, Q3a): a stage sent to another machine
# of its trabalho is held there until it ends — the queue's order inside it
# as usual —, through the impact window of a move (ImpactoDoMovimento,
# MoverNaFila); back to the automatic by another move, or by itself when
# that machine goes to the trash. A tecido pedido prints 15,5 m and runs
# them on the Calandra.
RSpec.describe "Mandar para outra máquina" do
  let(:sem_falta) { instance_double(AguardandoMaterial, avisos_do_pedido: [], do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:pessoa) { create(:user) }
  let!(:lenta) { maquina("Calandra 2", 15.5) }
  let!(:rapida) { maquina("Calandra 3", 31) }
  let!(:pedido) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 1.hour) } }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
  end

  def maquina(nome, por_hora)
    Maquina.new(nome: nome).tap { |m| m.trabalhos.build(trabalho: "calandra", por_hora: por_hora) }.tap(&:save!)
  end

  def fila
    FilaDeProducao.call(agora: quarta, aguardando: sem_falta)
  end

  def calandra(f = fila)
    f.previsao(pedido).vezes.find { |v| v.etapa.chave == "calandra" }
  end

  def mandar(para, de: rapida, motivo: nil)
    MovimentoDaFila.create!(pedido: pedido, user: pessoa, etapa: "calandra", setor: "estamparia", de: 1, de_maquina: de, para_maquina: para, motivo: motivo)
  end

  describe "the queue" do
    it "puts a held stage only on its machine, and back on the automatic with an empty move" do
      expect(calandra.maquina).to eq(rapida)
      presa = mandar(lenta)
      expect([ calandra.maquina, calandra.horas, calandra.fixacao ]).to eq([ lenta, 1.0, presa ])

      mandar(nil, de: lenta)
      expect([ calandra.maquina, calandra.fixacao ]).to eq([ rapida, nil ])
    end

    it "lets a held stage go back to the automatic when its machine goes to the trash" do
      mandar(lenta)
      lenta.excluir!(changed_by: "127.0.0.1")
      expect(calandra.maquina).to eq(rapida)
    end

    it "keeps the moves of place and the machine holds apart" do
      lugar = MovimentoDaFila.create!(pedido: pedido, user: pessoa, etapa: "calandra", setor: "estamparia", de: 2, para: 1, ordem_em: quarta - 2.days)
      presa = mandar(lenta)

      expect([ MovimentoDaFila.ordens.values, MovimentoDaFila.fixacoes.values ]).to eq([ [ lugar ], [ presa ] ])
      expect([ presa.de_maquina?, presa.voltou?, lugar.de_maquina?, lugar.voltou? ]).to eq([ true, false, false, false ])
      expect([ calandra.movimento, calandra.fixacao ]).to eq([ lugar, presa ])
    end
  end

  describe "the impact window" do
    def impacto(**movimento)
      ImpactoDoMovimento.call(fila, pedido: pedido, etapa: "calandra", **movimento)
    end

    it "sends it to another of its machines: its previsão before and after, saved held there" do
      ida = impacto(maquina: lenta.uuid)
      antes, depois = ida.movidos.fetch(pedido)

      expect([ ida.tipo, ida.maquinas, ida.para_maquina, ida.muda? ]).to eq([ :maquina, [ lenta, rapida ], lenta, true ])
      expect(depois - antes).to eq(30.minutes)
      MoverNaFila.call(ida, user: pessoa, motivo: "a Calandra 3 vai trocar o feltro")
      expect(MovimentoDaFila.fixacoes.values.sole.then { |m| [ m.de_maquina, m.para_maquina, m.user, m.motivo ] }).to eq([ rapida, lenta, pessoa, "a Calandra 3 vai trocar o feltro" ])
      expect(impacto(maquina: lenta.uuid).muda?).to be(false)
    end

    it "takes a held one back to the automatic" do
      mandar(lenta)
      volta = impacto(automatico: true)
      expect([ volta.tipo, volta.movimentos.sole.para_maquina, volta.movidos.fetch(pedido).then { |de, para| para < de } ]).to eq([ :automatico, nil, true ])
    end

    it "refuses a machine that doesn't do it, a stage with one machine, and an automatic one back" do
      outra = Maquina.new(nome: "Epson").tap { |m| m.trabalhos.build(trabalho: "impressao_papel", por_hora: 100) }.tap(&:save!)
      expect { impacto(maquina: outra.uuid) }.to raise_error(ImpactoDoMovimento::Invalido, /doesn't do the Calandra.*expected one of Calandra 2, Calandra 3/)
      expect { impacto(automatico: true) }.to raise_error(ImpactoDoMovimento::Invalido, /not held on a machine/)
      lenta.excluir!(changed_by: "127.0.0.1")
      expect { impacto(maquina: rapida.uuid) }.to raise_error(ImpactoDoMovimento::Invalido, /has 1 machine\(s\); sending it needs two or more/)
    end
  end
end
