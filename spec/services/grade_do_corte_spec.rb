require "rails_helper"

RSpec.describe GradeDoCorte do
  def nomes(resultado)
    resultado[:tamanhos].map { |t| [ t[:nome], t[:numeros] ] }
  end

  describe ".deduzir" do
    it "reads one even number per size as the last of a Par pair (\"24 AO 34 - CABEDAL\")" do
      resultado = described_class.deduzir(%w[24 26 28])
      expect(resultado[:tipo]).to eq("par")
      expect(nomes(resultado)).to eq([ [ "23-24", %w[23 24] ], [ "25-26", %w[25 26] ], [ "27-28", %w[27 28] ] ])
    end

    it "reads one odd number per size as Ímpar (\"CABEDAL - 35 AO 43\")" do
      expect(described_class.deduzir(%w[35 37 39])[:tipo]).to eq("impar")
    end

    it "keeps written pairs and takes the parity from the last number (\"34-35 ao 42-43\")" do
      resultado = described_class.deduzir(%w[34-35 36-37])
      expect([ resultado[:tipo], nomes(resultado).first ]).to eq([ "impar", [ "34-35", %w[34 35] ] ])
    end

    it "makes irregular ranges Furada, keeping the names (\"22 AO 34\")" do
      resultado = described_class.deduzir(%w[20-21 22-23 24-25-26 30])
      expect(resultado[:tipo]).to eq("furada")
      expect(nomes(resultado)).to eq([ [ "20-21", %w[20 21] ], [ "22-23", %w[22 23] ], [ "24-25-26", %w[24 25 26] ], [ "30", %w[30] ] ])
    end

    it "treats pairs with mixed parity as Furada" do
      expect(described_class.deduzir(%w[23-24 25-26 27-28 30-31])[:tipo]).to eq("furada")
    end

    it "recognizes P/M/G labels, numbers still unknown" do
      resultado = described_class.deduzir(%w[p M g])
      expect([ resultado[:tipo], nomes(resultado) ]).to eq([ "pmg", [ [ "P", [] ], [ "M", [] ], [ "G", [] ] ] ])
    end

    it "deduces nothing from a detected placeholder (\"Size 1\") or no sizes" do
      expect([ described_class.deduzir([ "Size 1" ]), described_class.deduzir([]) ]).to eq([ nil, nil ])
    end
  end

  describe ".ler" do
    it "completes a single number into its Par pair" do
      expect(described_class.ler("par", rotulo: nil, tamanhos: "30")).to eq(nome: "29-30", numeros: %w[29 30])
    end

    it "refuses a pair of the other parity, naming the value and the expected shape" do
      expect { described_class.ler("par", rotulo: nil, tamanhos: "30-31") }
        .to raise_error(GradeDoCorte::Invalido, /"30-31" isn't a Par pair.*e\.g\. 29-30/)
    end

    it "refuses numbers that aren't consecutive" do
      expect { described_class.ler("impar", rotulo: nil, tamanhos: "33-35") }.to raise_error(GradeDoCorte::Invalido)
    end

    it "names a Furada size by its label, else by its numbers" do
      expect(described_class.ler("furada", rotulo: "", tamanhos: "24-25-26")).to eq(nome: "24-25-26", numeros: %w[24 25 26])
      expect(described_class.ler("furada", rotulo: "Grande", tamanhos: "30")).to eq(nome: "Grande", numeros: %w[30])
    end

    it "refuses a Furada size with words or repeated numbers" do
      expect { described_class.ler("furada", rotulo: nil, tamanhos: "24 ao 26") }.to raise_error(GradeDoCorte::Invalido, /"24 ao 26"/)
      expect { described_class.ler("furada", rotulo: nil, tamanhos: "24-24") }.to raise_error(GradeDoCorte::Invalido)
    end

    it "needs a P/M/G label; its numbers are optional" do
      expect(described_class.ler("pmg", rotulo: "p", tamanhos: "")).to eq(nome: "P", numeros: [])
      expect { described_class.ler("pmg", rotulo: " ", tamanhos: "33-34") }.to raise_error(GradeDoCorte::Invalido, /needs its label/)
    end

    it "refuses an unknown grade type" do
      expect { described_class.ler("dupla", rotulo: nil, tamanhos: "30") }.to raise_error(GradeDoCorte::Invalido, /"dupla".*par, impar, pmg, furada/)
    end
  end
end
