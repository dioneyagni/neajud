require "rails_helper"

RSpec.describe NomeDoArquivo do
  def ler(nome) = described_class.ler(nome, partes: [ "Lateral", "Língua", "Cabedal" ])

  # The team's real file names (dev data, 01/10/2026).
  it "takes a leading number as the referência and leaves parts and sizes out of the name" do
    expect(ler("19-BLUEY PTO-LINGUA")).to eq(referencia: "19", nome: "BLUEY PTO")
    expect(ler("20-base-LATERAL-29_30")).to eq(referencia: "20", nome: "base")
    expect(ler("21-GATO PRETO.tif")).to eq(referencia: "21", nome: "GATO PRETO")
  end

  it "has no referência without a leading number, and no name when only numbers and parts are left" do
    expect(ler("Bluey Azul")).to eq(referencia: nil, nome: "Bluey Azul")
    expect(ler("39")).to eq(referencia: "39", nome: nil)
    expect(ler("Lateral-29-30")).to eq(referencia: nil, nome: nil)
  end
end
