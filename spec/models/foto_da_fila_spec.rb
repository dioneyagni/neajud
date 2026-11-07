require "rails_helper"

# Painel 3/4b: the photo of a turno, its stages' hours, and the viradas of
# the turno under way.
RSpec.describe FotoDaFila do
  let(:turno) { Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a) }
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:pedido) { create(:pedido, tipo: "tecido") }

  def foto(inicio)
    described_class.create!(turno: turno, data: inicio.to_date, inicio: inicio, fim: inicio + 4.hours)
  end

  it "finds a turno's photo, the ones over and the ones past 7 days" do
    velha, nova = foto(quarta - 8.days), foto(quarta)
    ocorrencia = CalendarioDeProducao::Ocorrencia.new(turno: turno, data: quarta.to_date)

    expect(described_class.do_turno(ocorrencia)).to eq(nova)
    expect(described_class.do_turno(nil)).to be_nil
    expect(described_class.terminadas(quarta + 1.hour)).to eq([ velha ])
    expect(described_class.vencidas(quarta)).to eq([ velha ])
    expect { foto(quarta) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "gives a stage's hours inside a period, and whether it was to end in the turno" do
    vez = foto(quarta).vezes.create!(pedido: pedido, etapa: "impressao", setor: "impressao", fim: quarta + 5.hours,
                                     trechos: [ { "inicio" => quarta.iso8601, "fim" => (quarta + 1.5.hours).iso8601 }, { "inicio" => (quarta + 5.hours).iso8601, "fim" => (quarta + 6.hours).iso8601 } ])

    expect(vez.horas_em(quarta...(quarta + 4.hours))).to eq(1.5)
    expect(vez.horas_em((quarta + 1.hour)...(quarta + 9.hours))).to eq(1.5)
    expect(vez.terminaria_no_turno?).to be(false)
    expect(vez.tap { |v| v.fim = quarta + 1.hour }.terminaria_no_turno?).to be(true)
  end

  it "keeps the viradas of the turno under way apart" do
    dados = { pedido: pedido, turno_nome: "Manhã", data: quarta.to_date, de: quarta }
    atual = ViradaDoPedido.create!(**dados, turno_fim: quarta + 4.hours, passou_a_atrasar: true)
    ViradaDoPedido.create!(**dados, turno_fim: quarta)

    expect(ViradaDoPedido.do_turno_de(quarta + 1.hour).atrasaram).to eq([ atual ])
    expect(ViradaDoPedido.do_turno_de(quarta + 4.hours)).to be_empty
  end
end
