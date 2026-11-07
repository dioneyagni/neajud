require "rails_helper"
require_relative "../support/producao_tecido"

# Painel 3/4b3 (the form of Q16a): the lanes of who crossed a pedido in its
# faixa's timeline. Here the other pedido passed ahead of it on the
# Impressão, and its Calandra didn't end at a virada: one lane, both
# stages, in the Manhã. A tecido prints 15,5 m in an hour.
RSpec.describe CruzadasNoTempo do
  let(:sem_falta) { instance_double(AguardandoMaterial, do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let!(:outro) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 2.hours) } }
  let!(:pedido) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 1.hour) } }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: 31)
    MovimentoDaFila.create!(pedido: outro, user: create(:user), etapa: "impressao", setor: "impressao", de: 2, para: 1, motivo: "urgente",
                            empurrados: [ { "pedido_id" => pedido.id, "de" => quarta.iso8601, "para" => quarta.iso8601 } ])
    ViradaDoPedido.create!(pedido: pedido, turno_nome: "Manhã", data: quarta.to_date, turno_fim: quarta + 4.hours, de: quarta - 1.day,
                           nao_terminaram: [ { "pedido" => outro.uuid, "etapa" => "Calandra", "veio_de" => "Manhã", "a_frente" => true } ])
  end

  def cruzadas
    fila = FilaDeProducao.call(agora: quarta, aguardando: sem_falta)
    historicos = { pedido.id => MovimentoDaFila.do_pedido(pedido).to_a + pedido.viradas_do_pedido.to_a }
    cruzamentos = CruzamentosDoPedido.call([ pedido ], historicos: historicos, viradas: ViradaDoPedido.all, visiveis: Pedido.all)[pedido.id]
    TempoDoPedido.call(LinhaDoPainel.call(pedido.reload, aguardando: sem_falta, fila: fila), fila: fila, cruzamentos: cruzamentos).cruzadas
  end

  it "draws a lane per pedido that crossed it, its stages where they crossed in the same turnos" do
    expect(cruzadas.map { |c| [ c.outro, c.etapas, c.celulas, c.feita, c.cruzamentos.size ] }).to eq([ [ outro, %w[Impressão Calandra], [ 0.38 ], false, 2 ] ])
  end

  it "says a stage already done, with nothing to draw" do
    RegistrarBaixaService.call(outro, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
    RegistrarBaixaService.call(outro, etapa: "calandra", nivel: "pedido", medida: "15,5", confirmar: true)
    expect(cruzadas.map { |c| [ c.etapas, c.celulas, c.feita ] }).to eq([ [ %w[Impressão Calandra], [ nil ], true ] ])
  end
end
