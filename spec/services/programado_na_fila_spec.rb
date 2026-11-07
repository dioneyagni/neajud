require "rails_helper"
require_relative "../support/producao_tecido"

# Painel 3/4b (decided 07/11/2026): what the photos programmed, against the
# queue of now — "veio de · adiada N turnos" only for a turno the stage was
# to end in (Q3a), and the hours programmed for the turno or the day still
# to do (Q7a). A tecido pedido prints 15,5 m in an hour and runs them on the
# Calandra in half an hour.
RSpec.describe ProgramadoNaFila do
  include ActiveSupport::Testing::TimeHelpers

  let(:sem_falta) { instance_double(AguardandoMaterial, do_pedido: []) }
  # Wednesday, as the Manhã starts.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let!(:manha) { Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a) }
  let!(:tarde) { Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a) }
  let!(:primeiro) { tecido(quarta - 3.hours) }
  let!(:segundo) { tecido(quarta - 2.hours) }
  let!(:terceiro) { tecido(quarta - 1.hour) }

  before do
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: 31)
  end

  def tecido(confirmado_em)
    pedido_tecido_confirmado.tap { |pedido| pedido.update_columns(confirmado_em: confirmado_em) }
  end

  def foto(agora)
    travel_to(agora) { TirarFotoDaFila.call(agora: agora, aguardando: sem_falta) }
  end

  def programado(agora, fotos: FotoDaFila.all)
    described_class.new(fotos, FilaDeProducao.call(agora: agora, aguardando: sem_falta))
  end

  # A stage done is out of the queue: asked as a bare Vez.
  def adiamento(agora, pedido, etapa = "impressao")
    fila = FilaDeProducao.call(agora: agora, aguardando: sem_falta)
    vez = fila.previsao(pedido).vezes.find { |v| v.etapa.chave == etapa }
    vez ||= FilaDeProducao::Vez.new(pedido: pedido, etapa: EtapasProducao.etapa(pedido.tipo, etapa, pedido: pedido))
    described_class.new(FotoDaFila.all, fila).adiamento(vez)&.to_h
  end

  def terminar_impressao(pedido)
    RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
  end

  it "marks a stage the photo had end in a turno already over, the first such turno and how many" do
    foto(quarta)
    # Wednesday's Tarde, nothing done in the Manhã.
    expect(adiamento(quarta + 5.5.hours, terceiro, "calandra")).to eq(veio_de: "Manhã", veio_em: quarta.to_date, turnos: 1)

    foto(quarta + 5.hours)
    expect(adiamento(quarta + 1.day, primeiro)).to eq(veio_de: "Manhã", veio_em: quarta.to_date, turnos: 2)
  end

  it "doesn't mark a stage the photo had end later, nor one done, nor without photos" do
    foto(quarta)
    terminar_impressao(primeiro)

    # The photo's turno is still under way; then the stage is done.
    expect(adiamento(quarta + 1.hour, segundo)).to be_nil
    expect(adiamento(quarta + 5.5.hours, primeiro)).to be_nil
    expect(programado(quarta + 5.5.hours, fotos: FotoDaFila.none).pendentes_do_dia("impressao")).to be_nil
  end

  # Q3a: a stage only passing through a turno (it would end in a later one) didn't fall behind.
  it "doesn't mark a stage that was only passing through the turno" do
    manha.update!(fim: "08:30")
    tarde.destroy!
    foto(quarta)

    expect(FotoDaFila.last.vezes.find_by(pedido: primeiro, etapa: "impressao").fim.to_date).to eq(quarta.to_date + 1)
    expect(adiamento(quarta + 1.day + 10.minutes, primeiro)).to be_nil
  end

  it "counts the hours the turno's photo, and the day's first, programmed there and are still to do" do
    foto(quarta)
    # 10:00: the Impressão had 3 h in the Manhã (08:00–11:00), none done.
    expect(programado(quarta + 2.hours).pendentes_do_turno("impressao", CalendarioDeProducao.new.agora(quarta + 2.hours))).to eq(3.0)

    terminar_impressao(primeiro)
    agora = quarta + 2.hours
    expect(programado(agora).pendentes_do_turno("impressao", CalendarioDeProducao.new.agora(agora))).to eq(2.0)
    # The Tarde has no photo yet; the day's is the Manhã's.
    expect(programado(quarta + 5.5.hours).pendentes_do_turno("impressao", CalendarioDeProducao.new.agora(quarta + 5.5.hours))).to be_nil
    expect(programado(quarta + 5.5.hours).pendentes_do_dia("impressao")).to eq(2.0)
  end
end
