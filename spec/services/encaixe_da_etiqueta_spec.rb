require "rails_helper"
require_relative "../support/etiquetas_dtf"

# Etapa 2.6b1 (decided 13/10/2026): each DTF size's fit on the film, stored
# on its file and redone when its measure, spacing or the film change.
RSpec.describe EncaixeDaEtiqueta do
  it "fits copies across the useful width with the spacing, both ways" do
    # (570 + 1,5) / (16,17 + 1,5) = 32,3 → 32 across; the row 17,02 + 1,5 tall.
    expect(described_class.calcular([ 16.17, 17.02 ], largura_util_mm: 570, espacamento_mm: 1.5)).to include(
      "em_pe" => { "por_fileira" => 32, "passo_mm" => 18.52 }, "girada" => { "por_fileira" => 30, "passo_mm" => 17.67 })
  end

  it "leaves out an orientation that doesn't fit, and has nothing without a measure" do
    encaixe = described_class.calcular([ 580, 100 ], largura_util_mm: 570, espacamento_mm: 1.5)
    expect([ encaixe["em_pe"], encaixe["girada"]["por_fileira"] ]).to eq([ nil, 5 ])
    expect(described_class.calcular(nil, largura_util_mm: 570, espacamento_mm: 1.5)).to be_nil
  end

  it "is stored when the size's version is processed, and follows the spacing and the film" do
    arquivo = criar_etiqueta_dtf(tamanhos: { "P" => [ 191, 201 ] }).arquivos.first
    expect(arquivo.reload.encaixe_dtf["em_pe"]).to eq("por_fileira" => 32, "passo_mm" => 18.52)
    arquivo.arte.update!(espacamento_mm: 3)
    expect(arquivo.reload.encaixe_dtf["em_pe"]).to eq("por_fileira" => 29, "passo_mm" => 20.02)
    Empresa.atual.update!(margem_filme_dtf_mm: 50)
    expect(arquivo.reload.encaixe_dtf).to include("largura_util_mm" => 500, "em_pe" => { "por_fileira" => 26, "passo_mm" => 20.02 })
  end

  it "is dropped when the arte stops being a DTF" do
    arte = criar_etiqueta_dtf
    arte.update!(tipo: "corrida")
    expect(arte.arquivos.first.reload.encaixe_dtf).to be_nil
  end
end
