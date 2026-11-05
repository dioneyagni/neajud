require "rails_helper"

# Painel 1/4 (Q6a): a stage's cell from its lines' states.
RSpec.describe CelulaDoPainel do
  def situacao(estado, aguardando = nil)
    RegistrarBaixaService::Situacao.new(estado: estado, aguardando: aguardando)
  end

  def celula(estados, confirmado: true)
    c = described_class.da_etapa(estados, confirmado: confirmado)
    [ c.estado, c.texto ]
  end

  it "says done, in progress with feitas/total, may start or waits for what" do
    expect(celula([ situacao(:feita), situacao(:feita) ])).to eq([ :feita, "feita" ])
    expect(celula([ situacao(:feita), situacao(:aberta), situacao(:aberta) ])).to eq([ :andamento, "1/3" ])
    expect(celula([ situacao(:aberta), situacao(:aguardando, "Corte") ])).to eq([ :pode_comecar, "pode começar" ])
    expect(celula([ situacao(:aguardando, "Impressão"), situacao(:aguardando, "Corte") ])).to eq([ :travada, "espera Impressão e Corte" ])
  end

  it "is not its turn before confirming, and absent without lines" do
    expect(celula([ situacao(:aberta) ], confirmado: false)).to eq([ :ainda_nao, "—" ])
    expect(celula([])).to eq([ :nao_tem, nil ])
  end

  it "gives the % of an in-progress cell" do
    expect(described_class.da_etapa([ situacao(:feita), situacao(:aberta) ], confirmado: true).percentual).to eq(50)
  end

  it "refuses an unknown state, naming the expected ones" do
    expect { described_class.nova(:programada) }.to raise_error(ArgumentError, /:programada is not a Painel cell state; expected one of feita/)
  end
end
