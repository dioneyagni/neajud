require "rails_helper"

# Painel 2/4a (decided 05/11/2026): one rhythm per type × stage, in the
# stage's baixa unit; the measured one in use unless the dono fixes his (Q5a).
RSpec.describe RitmoProducao do
  let(:medida) { RitmoMedido::Medida.new(valor: 4.6, turnos: 12) }

  it "is in the unit of the stage's baixa, or the paper's meters (the calçado's Estamparia, Painel 2/4a2)" do
    expect([ described_class.de("calcado", "impressao").unidade, described_class.de("calcado", "estamparia").unidade,
             described_class.de("calcado", "conferencia").unidade, described_class.de("dtf", "corte").unidade ])
      .to eq([ "m/h", "m/h", "peças/h", "unidades/h" ])
  end

  # Painel 2/4a2 (decided 06/11/2026): the calçado's Corte is the cutting machine.
  describe "the cutting machine" do
    let(:corte) { described_class.de("calcado", "corte") }

    it "has the defaults until the dono types his, and refuses 0" do
      expect([ corte.maquina_de_corte?, described_class.de("dtf", "corte").maquina_de_corte? ]).to eq([ true, false ])
      expect(described_class::MAQUINA_PADRAO.keys.map { |campo| corte.maquina(campo) }).to eq([ 100.0, 2.0, 5.0, 50.0, 10.0 ])
      corte.velocidade_mm_s = 120
      expect(corte.maquina(:velocidade_mm_s)).to eq(120.0)
      corte.troca_min = 0
      expect(corte.tap(&:valid?).errors[:troca_min].first).to include("must be more than 0 (blank = the default)")
    end

    it "uses the measured aproveitamento, else the machine time alone" do
      expect([ corte.em_uso(medida.tap { |m| m.valor = 0.62 }), corte.origem_em_uso(medida) ]).to eq([ 0.62, "medido" ])
      expect([ corte.em_uso(nil), corte.origem_em_uso(nil) ]).to eq([ 1.0, "informado" ])
      corte.fixar_informado = true
      expect(corte.em_uso(medida)).to eq(1.0)
    end
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
