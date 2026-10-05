require "rails_helper"

RSpec.describe NomeDoArquivo do
  def ler(nome) = described_class.ler(nome, partes: [ "Lateral", "Língua", "Cabedal" ])

  # The team's real file names (dev data, 01/10/2026).
  it "takes a leading number as the referência and leaves parts and sizes out of the name" do
    expect(ler("19-BLUEY PTO-LINGUA")).to eq(referencia: "19", nome: "BLUEY PTO", tamanho: nil, parte: "Língua")
    expect(ler("20-base-LATERAL-29_30")).to eq(referencia: "20", nome: "base", tamanho: "29-30", parte: "Lateral")
    expect(ler("21-GATO PRETO.tif")).to eq(referencia: "21", nome: "GATO PRETO", tamanho: nil, parte: nil)
  end

  it "has no referência without a leading number, and no name when only numbers and parts are left" do
    expect(ler("Bluey Azul")).to eq(referencia: nil, nome: "Bluey Azul", tamanho: nil, parte: nil)
    expect(ler("39")).to eq(referencia: "39", nome: nil, tamanho: nil, parte: nil)
    expect(ler("Lateral-29-30")).to eq(referencia: nil, nome: nil, tamanho: "29-30", parte: "Lateral")
  end

  # Etapa 1.2 (2/3): the size goes to the file, the measure nowhere.
  it "reads a P/M/G label as the size and drops measures from the name" do
    expect(ler("865-ARCOVERDE - G - 2,8 X 2")).to eq(referencia: "865", nome: "ARCOVERDE", tamanho: "G", parte: nil)
    expect(ler("845-PINDOBAÇU-P-1,3x2,6")).to eq(referencia: "845", nome: "PINDOBAÇU", tamanho: "P", parte: nil)
  end

  it "keeps a lower-case single letter in the name: it is more likely a word than a size" do
    expect(ler("12-Casa g")[:tamanho]).to be_nil
  end

  # Etapa 1.2 (2/3, parte 3): real leftovers of copies in the dev data.
  it "drops NEW and Copia from the name" do
    expect(ler("863-ARCOVERDE - P - 1,9 X 1,3 NEW")[:nome]).to eq("ARCOVERDE")
    expect(ler("846-PINDOBAÇU-M-1,6x3,2 - Copia")[:nome]).to eq("PINDOBAÇU")
  end
end
