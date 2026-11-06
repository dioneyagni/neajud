require "rails_helper"

# Painel 2/4a (decided 05/11/2026): one rhythm per type × stage, in the
# stage's baixa unit; the measured one in use unless the dono fixes his (Q5a).
RSpec.describe RitmoProducao do
  let(:medida) { RitmoMedido::Medida.new(por_hora: 4.6, turnos: 12) }

  it "is in the unit of the stage's baixa" do
    expect([ described_class.de("calcado", "impressao").unidade, described_class.de("calcado", "estamparia").unidade, described_class.de("dtf", "corte").unidade ])
      .to eq([ "m/h", "peças/h", "unidades/h" ])
  end

  it "refuses a stage the type doesn't have, and a rhythm of 0" do
    expect(described_class.de("dtf", "estamparia").tap(&:valid?).errors[:etapa].first).to include('unknown production stage "estamparia" for dtf')
    expect(described_class.new(tipo: "calcado", etapa: "corte", por_hora: 0).tap(&:valid?).errors[:por_hora].first).to include("must be more than 0")
  end

  it "uses the measured one, the typed one without it, and the typed one when fixed" do
    ritmo = described_class.new(tipo: "calcado", etapa: "impressao", por_hora: 5)
    expect([ ritmo.em_uso(medida), ritmo.origem_em_uso(medida) ]).to eq([ 4.6, "medido" ])
    expect([ ritmo.em_uso(nil), ritmo.origem_em_uso(nil) ]).to eq([ 5, "informado" ])
    ritmo.fixar_informado = true
    expect([ ritmo.em_uso(medida), ritmo.origem_em_uso(medida) ]).to eq([ 5, "informado" ])
    expect(described_class.new(tipo: "calcado", etapa: "impressao").origem_em_uso(nil)).to be_nil
  end
end
