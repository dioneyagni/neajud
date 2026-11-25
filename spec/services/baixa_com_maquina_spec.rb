require "rails_helper"
require_relative "../support/producao_tecido"

# Máquinas 4/5a (decided 20–24/11/2026): a stage with machines takes the
# one its baixa was done on (Q4a, one per baixa — Q2a); the rest of a
# started stage stays on the machine of its last baixa, over a hold, which
# moves to it as a movement of the baixa (Q1a). The editor opens on the
# last baixa's machine, else the held one, else the queue's. A tecido
# pedido prints 15,5 m and runs a 12,5 m and a 3 m line on the Calandra.
RSpec.describe "Baixa com a máquina" do
  let(:sem_falta) { instance_double(AguardandoMaterial, avisos_do_pedido: [], do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:pessoa) { create(:user) }
  let!(:lenta) { maquina("Calandra 2", 15.5) }
  let!(:rapida) { maquina("Calandra 3", 31) }
  let!(:pedido) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 1.hour) } }
  let(:etapa) { EtapasProducao.etapa("tecido", "calandra", pedido: pedido) }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
    RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
  end

  def maquina(nome, por_hora, trabalho: "calandra")
    Maquina.new(nome: nome).tap { |m| m.trabalhos.build(trabalho: trabalho, por_hora: por_hora) }.tap(&:save!)
  end

  def calandra
    FilaDeProducao.call(agora: quarta, aguardando: sem_falta).previsao(pedido).vezes.find { |v| v.etapa.chave == "calandra" }
  end

  def primeira_linha
    EstadoDasEtapas.call(pedido)["calandra"].keys.first
  end

  def baixa(maquina, medida: "12,5")
    RegistrarBaixaService.call(pedido, etapa: "calandra", nivel: "linha", alvo: primeira_linha, medida: medida, confirmar: true, maquina: maquina&.uuid, user: pessoa)
  end

  def prender(em)
    MovimentoDaFila.create!(pedido: pedido, user: pessoa, etapa: "calandra", setor: "estamparia", de_maquina: (rapida if em == lenta), para_maquina: em)
  end

  describe MaquinaDaBaixa do
    it "offers the active machines doing the stage's trabalho, the first registered first" do
      maquina("Epson", 100, trabalho: "impressao_dtf")
      maquina("Calandra 4", 20).excluir!(changed_by: "127.0.0.1")
      expect(MaquinaDaBaixa.opcoes(pedido, etapa)).to eq([ lenta, rapida ])
      expect(MaquinaDaBaixa.opcoes(pedido, EtapasProducao.etapa("tecido", "impressao", pedido: pedido))).to eq([])
    end

    it "takes the one given, the only one without asking, and refuses a missing or a foreign machine" do
      expect(MaquinaDaBaixa.escolher(pedido, etapa, rapida.uuid)).to eq(rapida)
      expect { MaquinaDaBaixa.escolher(pedido, etapa, "") }.to raise_error(MaquinaDaBaixa::Invalida, /Which machine did the Calandra\? Expected one of Calandra 2, Calandra 3/)
      expect { MaquinaDaBaixa.escolher(pedido, etapa, "nope") }.to raise_error(MaquinaDaBaixa::Invalida, /"nope" doesn't do the Calandra; expected one of Calandra 2, Calandra 3/)

      lenta.excluir!(changed_by: "127.0.0.1")
      expect(MaquinaDaBaixa.escolher(pedido, etapa, nil)).to eq(rapida)
      impressao = EtapasProducao.etapa("tecido", "impressao", pedido: pedido)
      expect(MaquinaDaBaixa.escolher(pedido, impressao, nil)).to be_nil
      expect { MaquinaDaBaixa.escolher(pedido, impressao, rapida.uuid) }.to raise_error(MaquinaDaBaixa::Invalida, /Impressão has no machine/)
    end

    it "suggests the queue's machine, then the held one, then the last baixa's — the queue built only when needed" do
      fila = -> { FilaDeProducao.call(agora: quarta, aguardando: sem_falta) }
      sugerida = -> { MaquinaDaBaixa.sugerida(pedido, etapa, fixacoes: MovimentoDaFila.fixacoes, &fila).then { |s| [ s.maquina, s.origem ] } }
      expect(sugerida.call).to eq([ rapida, :programada ])

      prender(lenta)
      expect(sugerida.call).to eq([ lenta, :presa ])

      baixa(rapida)
      expect(MaquinaDaBaixa.sugerida(pedido, etapa, fixacoes: MovimentoDaFila.fixacoes) { raise "the queue was built" }.origem).to eq(:baixa)
      expect(sugerida.call).to eq([ rapida, :baixa ])
    end
  end

  describe "the baixa" do
    it "saves the machine, and asks for one when the stage has two" do
      expect(baixa(nil).then { |r| [ r.estado, r.mensagem ] }).to eq([ :erro, "Which machine did the Calandra? Expected one of Calandra 2, Calandra 3" ])
      expect(baixa(lenta).baixa.maquina).to eq(lenta)
    end

    it "keeps the rest of a started stage on the machine of its last baixa" do
      expect(calandra.maquina).to eq(rapida)
      baixa(lenta)
      expect([ calandra.iniciada?, calandra.maquina, calandra.fixacao ]).to eq([ true, lenta, nil ])
      expect(MovimentoDaFila.count).to eq(0)
    end

    it "moves a hold on another machine to the baixa's, as the baixa's movement" do
      prender(rapida)
      resultado = baixa(lenta)
      troca = resultado.troca

      expect([ troca.de_maquina, troca.para_maquina, troca.baixa_producao, troca.user ]).to eq([ rapida, lenta, resultado.baixa, pessoa ])
      expect(MovimentoDaFila.fixacoes.values).to eq([ troca ])
      expect(calandra.maquina).to eq(lenta)
    end

    it "moves nothing when the baixa is on the machine it was held on" do
      prender(lenta)
      expect(baixa(lenta).troca).to be_nil
      expect(MovimentoDaFila.count).to eq(1)
    end
  end
end
