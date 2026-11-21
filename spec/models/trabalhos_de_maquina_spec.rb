require "rails_helper"

# Máquinas 1/5 (decided 20/11/2026): the fixed list of what a machine does.
RSpec.describe TrabalhosDeMaquina do
  it "gives every stage but the Conferência one trabalho, each stage real" do
    etapas = EtapasProducao.todas.flat_map { |tipo, lista| lista.map { |etapa| [ tipo, etapa.chave ] } }
    sem = etapas.reject { |tipo, etapa| described_class.da_etapa(tipo, etapa) }
    expect(sem).to eq([ %w[calcado conferencia] ])
    expect(described_class.todos.flat_map(&:etapas) - etapas).to eq([])
  end

  it "dubs both dublagem stages with one trabalho, and prints calçado and tecido paper with another" do
    expect([ described_class.da_etapa("tecido", "dublagem_final").chave, described_class.da_etapa("tecido", "impressao").chave ]).to eq(%w[dublagem impressao_papel])
  end

  it "has each trabalho's unit, none for the Corte do calçado (its parameters)" do
    expect(described_class.todos.to_h { |trabalho| [ trabalho.chave, trabalho.unidade ] })
      .to include("corte_calcado" => nil, "corte_dtf" => "unidades/h", "estamparia" => "m/h", "calandra" => "m/h")
  end

  it "raises on an unknown trabalho, naming the known ones" do
    expect { described_class.trabalho("prensa") }.to raise_error(ArgumentError, /Unknown machine trabalho "prensa"; expected one of impressao_papel/)
  end
end
