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
      expect(described_class::MAQUINA_PADRAO.keys.map { |campo| corte.parametro_do_corte(campo) }).to eq([ 100.0, 2.0, 5.0, 50.0, 10.0 ])
      corte.velocidade_mm_s = 120
      expect(corte.parametro_do_corte(:velocidade_mm_s)).to eq(120.0)
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

  # Painel 2/4b: a load over the rhythm in use; the machine's load is hours.
  it "says how many hours a load takes, none without a rhythm" do
    expect(described_class.new(tipo: "calcado", etapa: "impressao", por_hora: 5).horas(12, nil)).to eq(2.4)
    expect(described_class.new(tipo: "calcado", etapa: "impressao").horas(12, nil)).to be_nil
    expect(described_class.de("calcado", "corte").horas(1.24, medida.tap { |m| m.valor = 0.62 })).to eq(2.0)
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

  # Máquinas 1/5 (decided 20/11/2026, Q7a): a stage whose trabalho has
  # machines takes their sum; none, the one typed.
  describe "with machines" do
    def maquina(nome, **trabalhos)
      Maquina.new(nome: nome).tap { |m| trabalhos.each { |chave, por_hora| m.trabalhos.build(trabalho: chave.to_s, por_hora: por_hora) } }.tap(&:save!)
    end

    it "takes the active machines' sum as its informado, the typed one kept for when there are none" do
      ritmo = described_class.create!(tipo: "tecido", etapa: "calandra", por_hora: 25)
      maquina("Calandra 2", calandra: 40, dublagem: 30)
      terceira = maquina("Calandra 3", calandra: 40)
      fresco = described_class.de("tecido", "calandra")
      expect([ fresco.com_maquinas?, fresco.informado, fresco.em_uso(nil), fresco.origem_em_uso(nil), fresco.horas(40, nil) ]).to eq([ true, 80, 80, "informado", 0.5 ])
      expect([ described_class.de("tecido", "dublagem_final").informado, described_class.de("tecido", "impressao").informado ]).to eq([ 30, nil ])
      terceira.excluir!(changed_by: "127.0.0.1")
      expect([ described_class.de("tecido", "calandra").informado, ritmo.reload.por_hora ]).to eq([ 40, 25 ])
    end

    it "still gives way to the measured one, unless fixed" do
      maquina("Calandra 2", calandra: 40)
      ritmo = described_class.de("tecido", "calandra")
      expect(ritmo.em_uso(medida)).to eq(4.6)
      ritmo.fixar_informado = true
      expect(ritmo.em_uso(medida)).to eq(40)
    end

    it "reads every type × stage with its machines in one go" do
      maquina("Epson A", impressao_papel: 100)
      maquina("Epson B", impressao_papel: 100)
      fabrica = described_class.da_fabrica
      expect(fabrica.keys).to include(%w[calcado impressao], %w[tecido impressao], %w[calcado conferencia])
      expect([ fabrica[%w[calcado impressao]].informado, fabrica[%w[tecido impressao]].informado, fabrica[%w[calcado conferencia]].maquinas ]).to eq([ 200, 200, [] ])
    end

    it "cuts by each Corte do calçado machine's parameters, by its own row's without any" do
      corte = described_class.de("calcado", "corte")
      expect(corte.fontes_do_corte).to eq([ corte ])
      mesa = Maquina.new(nome: "Mesa 1").tap { |m| m.trabalhos.build(trabalho: "corte_calcado", velocidade_mm_s: 120) }.tap(&:save!)
      expect([ described_class.de("calcado", "corte").fontes_do_corte, described_class.de("calcado", "corte").informado ]).to eq([ mesa.trabalhos.to_a, nil ])
    end

    # Máquinas 2/5a (assumed 21/11/2026): a machine runs its share of the
    # rhythm in use — the measured one split like the informado.
    it "gives each machine its share of the rhythm, the measured one split by speed" do
      lenta = maquina("Calandra 2", calandra: 20).trabalho_de("calandra")
      rapida = maquina("Calandra 3", calandra: 60).trabalho_de("calandra")
      ritmo = described_class.de("tecido", "calandra")
      medido = RitmoMedido::Medida.new(valor: 40.0, turnos: 6)

      expect([ ritmo.parte_da_maquina(lenta), ritmo.parte_da_maquina(rapida) ]).to eq([ 0.25, 0.75 ])
      # 30 m alone on the 60 m/h one; measured 40 m/h for both, it does 30 of them.
      expect([ ritmo.horas(30, nil, parte: 0.75), ritmo.horas(30, medido, parte: 0.75) ]).to eq([ 0.5, 1.0 ])
      expect(described_class.de("calcado", "corte").parte_da_maquina(lenta)).to eq(1.0)
    end
  end
end
