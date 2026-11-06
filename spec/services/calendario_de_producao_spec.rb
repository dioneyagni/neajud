require "rails_helper"

# Painel 2/4a (decided 05/11/2026): the turnos on real days, minus the
# exceptions of the whole factory or of one stage (Q8a), after midnight too (Q10a).
RSpec.describe CalendarioDeProducao do
  let!(:manha) { Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: (1..6).to_a) }
  let!(:tarde) { Turno.create!(nome: "Tarde", inicio: "14:00", fim: "22:00", dias: (1..5).to_a) }
  # Wed 04/11/2026; the 1st is a Sunday.
  let(:quarta) { Date.new(2026, 11, 4) }

  def em(data, hhmm)
    Time.zone.parse("#{data.iso8601} #{hhmm}")
  end

  it "tells the turno on now, and none between turnos or on Sunday" do
    calendario = described_class.new
    expect(calendario.agora(em(quarta, "10:40")).turno).to eq(manha)
    expect(calendario.agora(em(quarta, "14:00")).turno).to eq(tarde)
    expect(calendario.agora(em(quarta, "23:00"))).to be_nil
    expect(calendario.agora(em(Date.new(2026, 11, 8), "10:00"))).to be_nil
  end

  it "finds the previous day's night turno after midnight" do
    noite = Turno.create!(nome: "Noite", inicio: "22:00", fim: "06:00", dias: [ 5 ])
    ocorrencia = described_class.new.agora(em(Date.new(2026, 11, 7), "03:00"))
    expect([ ocorrencia.turno, ocorrencia.data, ocorrencia.horas ]).to eq([ noite, Date.new(2026, 11, 6), 8.0 ])
  end

  it "tells the next turno when none is on" do
    calendario = described_class.new
    expect(calendario.proxima(em(quarta, "23:00")).then { |o| [ o.turno, o.data ] }).to eq([ manha, quarta + 1 ])
  end

  it "lists the turnos of a period in order, skipping the whole factory's days off" do
    ExcecaoCalendario.create!(data: quarta + 1, nome: "Recesso", origem: "manual")
    nomes = described_class.new.ocorrencias(de: em(quarta, "00:00"), ate: em(quarta + 3, "00:00")).map { |o| [ o.data.day, o.turno.nome ] }
    expect(nomes).to eq([ [ 4, "Manhã" ], [ 4, "Tarde" ], [ 6, "Manhã" ], [ 6, "Tarde" ] ])
  end

  it "takes only that turno when the exception names one" do
    ExcecaoCalendario.create!(data: quarta, nome: "Reunião", turno: tarde)
    nomes = described_class.new.ocorrencias(de: em(quarta, "00:00"), ate: em(quarta + 1, "00:00")).map { |o| o.turno.nome }
    expect(nomes).to eq([ "Manhã" ])
  end

  it "gives a stage no hours where it stops, and the others theirs" do
    ExcecaoCalendario.create!(data: quarta, nome: "Calandra parada", etapa: "calandra")
    calendario = described_class.new
    ocorrencia = calendario.agora(em(quarta, "10:00"))
    expect([ calendario.horas(ocorrencia, "calandra"), calendario.horas(ocorrencia, "impressao") ]).to eq([ 0.0, 8.0 ])
  end

  it "counts the hours left of a turno under way" do
    calendario = described_class.new
    ocorrencia = calendario.agora(em(quarta, "10:30"))
    expect(calendario.horas(ocorrencia, "impressao", desde: em(quarta, "10:30"))).to eq(3.5)
  end
end
