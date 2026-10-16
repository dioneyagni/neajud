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

  # Etapa 2.6b2 (decided 15/10/2026): the DTF prints (meters of film) and,
  # only when delivered cut, cuts the units printed after printing them.
  describe "the DTF" do
    it "reads its Impressão and Corte, the Corte only for a pedido delivered cut" do
      etapas = described_class.do_tipo("dtf")
      expect(etapas.map { |e| [ e.chave, e.medida, e.esperado, e.linhas, e.trava, e.unidade_da_medida ] }).to eq([
        [ "impressao", "metragem", "filme", "dtf", [], "m" ], [ "corte", "quantidade", "pecas", "dtf", %w[impressao], "unidades" ]
      ])
      expect(described_class.do_tipo("dtf", pedido: Pedido.new(tipo: "dtf", entrega: "rolo")).map(&:chave)).to eq(%w[impressao])
      expect(described_class.do_tipo("dtf", pedido: Pedido.new(tipo: "dtf", entrega: "cortada")).map(&:chave)).to eq(%w[impressao corte])
    end

    it "has no Corte for a pedido on the roll" do
      expect { described_class.etapa("dtf", "corte", pedido: Pedido.new(tipo: "dtf", entrega: "rolo")) }
        .to raise_error(described_class::Invalida, /unknown production stage "corte" for dtf \(this pedido\); expected one of impressao/)
    end

    it "raises naming a wrong condition" do
      errado = { "dtf" => [ { "chave" => "corte", "nome" => "Corte", "medida" => "quantidade", "esperado" => "pecas", "linhas" => "dtf", "niveis" => %w[linha], "quando" => { "entrega" => "dobrada", "cor" => "azul" } } ] }
      expect { described_class.send(:ler, errado) }.to raise_error(described_class::Invalida,
        'dtf/corte: quando entrega "dobrada" is not one of rolo, cortada; quando "cor" is not one of entrega')
    end
  end

  it "counts a calçado stage's quantity in pieces" do
    expect(described_class.etapa("calcado", "conferencia").unidade_da_medida).to eq("peças")
  end
end
