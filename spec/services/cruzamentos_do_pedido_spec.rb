require "rails_helper"
require_relative "../support/producao_tecido"

# Painel 3/4b2 (Q9a): who pushed a pedido and whom it pushed, by a move in
# the queue and by a virada.
RSpec.describe CruzamentosDoPedido do
  let(:user) { create(:user) }
  let!(:este) { pedido_tecido_confirmado }
  let!(:outro) { pedido_tecido_confirmado }
  let!(:terceiro) { pedido_tecido_confirmado }

  def mover(pedido, empurrados, em)
    MovimentoDaFila.create!(pedido: pedido, user: user, etapa: "impressao", setor: "impressao", de: 2, para: 1, motivo: "urgente", created_at: em,
                            empurrados: empurrados.map { |p| { "pedido_id" => p.id, "de" => em.iso8601, "para" => (em + 1.day).iso8601 } })
  end

  # a_frente: { uuid => was ahead of the virada's pedido }
  def virar(pedido, a_frente, em)
    ViradaDoPedido.create!(pedido: pedido, turno_nome: "Tarde", data: em.to_date, turno_fim: em + 4.hours, de: em, para: em + 1.day, created_at: em,
                           nao_terminaram: a_frente.map { |uuid, frente| { "pedido" => uuid, "etapa" => "Impressão", "veio_de" => "Manhã", "a_frente" => frente } })
  end

  def cruzamentos
    historicos = { este.id => (MovimentoDaFila.do_pedido(este).to_a + ViradaDoPedido.where(pedido: este).to_a) }
    described_class.call([ este ], historicos: historicos, viradas: ViradaDoPedido.all, visiveis: Pedido.all)[este.id]
  end

  it "lists the movers that pushed it, the ones its move pushed, and the viradas both ways, by time" do
    agora = Time.zone.parse("2026-11-04 10:00")
    mover(outro, [ este ], agora - 4.hours)
    mover(este, [ terceiro ], agora - 3.hours)
    # Its own stage and one behind it that didn't end either are no crossing.
    virar(este, { este.uuid => false, outro.uuid => true, terceiro.uuid => false }, agora - 2.hours)
    virar(terceiro, { este.uuid => true }, agora - 1.hour)
    virar(outro, { este.uuid => false }, agora - 1.hour)

    expect(cruzamentos.map { |c| [ c.outro, c.papel, c.tipo ] }).to eq([ [ outro, :empurrou, :movimento ], [ terceiro, :foi_empurrado, :movimento ],
                                                                         [ outro, :empurrou, :virada ], [ terceiro, :foi_empurrado, :virada ] ])
    expect(cruzamentos.map(&:etapa).compact).to eq(%w[Impressão Impressão])
  end

  it "leaves out a pedido the person doesn't see, and itself" do
    mover(este, [ este, outro ], Time.current)
    resultado = described_class.call([ este ], historicos: { este.id => MovimentoDaFila.do_pedido(este).to_a }, viradas: ViradaDoPedido.all,
                                               visiveis: Pedido.where.not(id: outro.id))[este.id]
    expect(resultado).to be_empty
  end
end
