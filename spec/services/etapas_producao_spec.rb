require "rails_helper"

# Etapa 2.2 (2/3, decided 07/10/2026): config/etapas_producao.yml.
RSpec.describe EtapasProducao do
  it "reads the calçado stages, in order, with their locks" do
    etapas = described_class.do_tipo("calcado")
    expect(etapas.map { |e| [ e.chave, e.medida, e.linhas, e.trava ] }).to eq([
      [ "impressao", "metragem", "impressao", [] ], [ "corte", "metragem", "corte", [] ],
      [ "estamparia", "quantidade", "impressao", %w[impressao corte] ], [ "conferencia", "quantidade", "impressao", %w[estamparia] ]
    ])
  end

  # A typo must never silently change what the factory may do.
  it "raises naming a wrong value and what was expected" do
    errado = { "calcado" => [ { "chave" => "corte", "nome" => "Corte", "medida" => "peso", "esperado" => "tecido", "linhas" => "corte", "niveis" => %w[linha lote], "trava" => %w[costura] } ] }
    expect { described_class.send(:ler, errado) }.to raise_error(described_class::Invalida,
      'calcado/corte: medida "peso" is not one of metragem, quantidade; nivel "lote" is not one of linha, referencia, pedido; trava "costura" is not a stage of this type')
  end

  it "raises on an unknown type or stage" do
    expect { described_class.do_tipo("tecido") }.to raise_error(described_class::Invalida, /no production stages for pedido type "tecido"/)
    expect { described_class.etapa("calcado", "costura") }.to raise_error(described_class::Invalida, /unknown production stage "costura"/)
  end
end
