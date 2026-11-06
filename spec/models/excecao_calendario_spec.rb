require "rails_helper"

# Painel 2/4a (decided 05/11/2026, Q8a): a day or turno off, for the whole
# factory or one stage.
RSpec.describe ExcecaoCalendario do
  let(:tarde) { Turno.create!(nome: "Tarde", inicio: "14:00", fim: "22:00", dias: (1..5).to_a) }
  let(:quarta) { Date.new(2026, 11, 4) }

  def ocorrencia(turno, data = quarta)
    CalendarioDeProducao::Ocorrencia.new(turno: turno, data: data, inicio: data.in_time_zone, fim: data.in_time_zone + 8.hours)
  end

  it "stops the whole factory, or only its stage, on its day" do
    fabrica = described_class.new(data: quarta, nome: "Recesso")
    calandra = described_class.new(data: quarta, nome: "Calandra parada", etapa: "calandra")
    expect([ fabrica.para?(ocorrencia(tarde), "corte"), calandra.para?(ocorrencia(tarde), "calandra"), calandra.para?(ocorrencia(tarde), "corte") ]).to eq([ true, true, false ])
    expect(fabrica.para?(ocorrencia(tarde, quarta + 1), "corte")).to be(false)
  end

  it "stops only its turno when it names one" do
    manha = Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: (1..5).to_a)
    excecao = described_class.new(data: quarta, nome: "Reunião", turno: tarde)
    expect([ excecao.para?(ocorrencia(tarde)), excecao.para?(ocorrencia(manha)) ]).to eq([ true, false ])
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
end
