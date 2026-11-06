require "rails_helper"
require_relative "../support/producao_calcado"

# Painel 2/4a2 / 2/4b: what a stage's lines weigh in its rhythm's unit.
RSpec.describe CargaDaEtapa do
  let(:pedido) { pedido_calcado_confirmado }

  def etapa(chave)
    EtapasProducao.etapa("calcado", chave)
  end

  def linhas(chave)
    LinhasDeProducao.call(pedido, etapa(chave))
  end

  it "is the lines' expected for a stage counted in its baixa's measure" do
    expect(described_class.call(pedido, etapa("conferencia"), linhas("conferencia"), RitmoProducao.de("calcado", "conferencia")).valor).to eq(20.0)
  end

  # The calçado's Estamparia is counted in pieces but its rhythm in paper.
  it "is the same lines' paper meters for a papel rhythm, built once per pedido" do
    papel = LinhasDeProducao.call(pedido, etapa("estamparia").dup.tap { |e| e.esperado = "papel" })
    memoria = {}
    carga = described_class.call(pedido, etapa("estamparia"), linhas("estamparia").first(1), RitmoProducao.de("calcado", "estamparia"), memoria: memoria)
    expect(carga.valor).to eq(papel.first.esperado.to_f)
    expect(memoria.keys).to eq([ [ :papel, pedido.id, "estamparia" ] ])
  end

  it "is the cutting machine's hours, from the material it ended on" do
    ritmo = RitmoProducao.de("calcado", "corte")
    outro = MateriaPrima.new
    tempo = TempoDoCorte.call(linhas("corte"), ritmo, anterior: outro)
    carga = described_class.call(pedido, etapa("corte"), linhas("corte"), ritmo, anterior: outro)
    expect([ carga.valor, carga.ultimo_material, carga.sem_medida ]).to eq([ tempo.horas, tempo.ultimo_material, [ "29-30" ] ])
  end
end
