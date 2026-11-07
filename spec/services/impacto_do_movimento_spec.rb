require "rails_helper"
require_relative "../support/producao_tecido"

# Painel 3/4a (decided 07/11/2026, Q3a, Q5a, Q6b, Q7c): what a move does
# before anyone confirms it — every previsão that gets worse, in any
# sector, the ones coming to be late first, which require the reason; and
# confirming it (MoverNaFila). A tecido pedido here prints 15,5 m in an
# hour and runs them on the Calandra in half an hour.
RSpec.describe ImpactoDoMovimento do
  let(:sem_falta) { instance_double(AguardandoMaterial, do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:pessoa) { create(:user) }
  let!(:primeiro) { tecido(quarta - 3.hours) }
  let!(:segundo) { tecido(quarta - 2.hours) }
  let!(:terceiro) { tecido(quarta - 1.hour) }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: 31)
  end

  def tecido(confirmado_em)
    pedido_tecido_confirmado.tap { |pedido| pedido.update_columns(confirmado_em: confirmado_em) }
  end

  def fila
    FilaDeProducao.call(agora: quarta, aguardando: sem_falta)
  end

  def impacto(**movimento)
    described_class.call(fila, **movimento)
  end

  def ordem
    fila.do_setor("impressao").map(&:pedido)
  end

  # A short day: the third's Impressão and the others' Calandras spill into Thursday.
  def dia_curto
    Turno.find_by(nome: "Manhã").update!(fim: "10:00")
    Turno.find_by(nome: "Tarde").destroy!
  end

  it "moves a stage to a place, every pushed pedido with its previsão before and after, in any sector" do
    i = impacto(pedido: terceiro, etapa: "impressao", posicao: 1)

    expect([ i.de, i.para, i.limite, i.total, i.exige_motivo? ]).to eq([ 3, 1, 1, 3, false ])
    # The third prints first; the Calandras follow their Impressões.
    expect(i.movidos).to eq(terceiro => [ quarta + 3.5.hours, quarta + 1.5.hours ])
    expect(i.empurrados.map { |e| [ e.pedido, e.de, e.para ] }).to eq([ [ primeiro, quarta + 1.5.hours, quarta + 2.5.hours ], [ segundo, quarta + 2.5.hours, quarta + 3.5.hours ] ])
  end

  it "puts the newly late first and requires the reason only for them" do
    primeiro.update!(prazo_entrega: quarta.to_date)
    segundo.update!(prazo_entrega: quarta.to_date - 1)
    i = impacto(pedido: terceiro, etapa: "impressao", posicao: 1)

    # The segundo was already late: it is pushed, but asks no reason.
    expect(i.empurrados.map { |e| [ e.pedido, e.passa_a_atrasar ] }).to eq([ [ primeiro, false ], [ segundo, false ] ])
    dia_curto
    late = impacto(pedido: terceiro, etapa: "impressao", posicao: 1)
    expect([ late.empurrados.first.pedido, late.empurrados.first.passa_a_atrasar, late.exige_motivo? ]).to eq([ primeiro, true, true ])
  end

  # Q6b: a stage under way (a baixa given) is not passed, nor moved.
  it "goes no higher than the stages under way, and doesn't move one" do
    RegistrarBaixaService.call(segundo, etapa: "impressao", nivel: "linha", alvo: EstadoDasEtapas.call(segundo)["impressao"].keys.first, medida: "12,5", confirmar: true)
    i = impacto(pedido: terceiro, etapa: "impressao", posicao: 1)

    expect([ i.limite, i.para, i.movimentos.sole.para ]).to eq([ 2, 2, 2 ])
    expect { impacto(pedido: segundo, etapa: "impressao", posicao: 3) }.to raise_error(ImpactoDoMovimento::Invalido, /under way/)
    expect { impacto(pedido: terceiro, etapa: "corte", posicao: 1) }.to raise_error(ImpactoDoMovimento::Invalido, /not in a queue/)
  end

  describe "confirmed" do
    it "saves the move with the pushed pedidos, and the order holds" do
      i = impacto(pedido: terceiro, etapa: "impressao", posicao: 1)
      movimento = MoverNaFila.call(i, user: pessoa, motivo: " cliente pediu urgência ").sole

      expect([ movimento.de, movimento.para, movimento.motivo, movimento.empurrados.map { |e| e["pedido_id"] } ]).to eq([ 3, 1, "cliente pediu urgência", [ primeiro.id, segundo.id ] ])
      expect(ordem).to eq([ terceiro, primeiro, segundo ])
    end

    it "refuses it without a reason when someone comes to be late" do
      primeiro.update!(prazo_entrega: quarta.to_date)
      dia_curto
      i = impacto(pedido: terceiro, etapa: "impressao", posicao: 1)

      expect { MoverNaFila.call(i, user: pessoa, motivo: "  ") }.to raise_error(MoverNaFila::SemMotivo, "##{primeiro.uuid.first(8)} would come to be late: say why")
      expect(MovimentoDaFila.count).to eq(0)
    end

    # Q4: what a cliente final reads — only a later day, no reason, no other pedido.
    it "tells each pedido pushed to a later day, in its history" do
      dia_curto
      MoverNaFila.call(impacto(pedido: terceiro, etapa: "impressao", posicao: 1), user: pessoa, motivo: "urgente")

      # The segundo is pushed too, but within Thursday.
      expect(EventoPedido.where(tipo: "previsao_mudou").map { |e| [ e.pedido, e.recado ] }).to eq([ [ primeiro, "qua 04/11 → qui 05/11" ] ])
    end

    it "takes one stage, or the whole sector, back to the arrival order" do
      MoverNaFila.call(impacto(pedido: terceiro, etapa: "impressao", posicao: 1), user: pessoa, motivo: nil)
      MoverNaFila.call(impacto(pedido: segundo, etapa: "impressao", posicao: 1), user: pessoa, motivo: nil)
      expect(ordem).to eq([ segundo, terceiro, primeiro ])

      volta = impacto(pedido: terceiro, etapa: "impressao")
      expect([ volta.tipo, volta.de, volta.para ]).to eq([ :chegada, 2, 3 ])
      MoverNaFila.call(volta, user: pessoa, motivo: nil)
      expect(ordem).to eq([ segundo, primeiro, terceiro ])

      tudo = impacto(setor: "impressao")
      expect(tudo.movimentos.map(&:pedido)).to eq([ segundo ])
      MoverNaFila.call(tudo, user: pessoa, motivo: nil)
      expect(ordem).to eq([ primeiro, segundo, terceiro ])
      expect { impacto(setor: "impressao") }.to raise_error(ImpactoDoMovimento::Invalido, /no moved stage/)
    end
  end
end
