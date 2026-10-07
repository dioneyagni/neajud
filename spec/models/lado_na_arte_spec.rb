require "rails_helper"

# Etapa 1.2 (3/3, parte 3c, decided 06-07/10/2026): a mirrored part's file
# may say its side.
RSpec.describe LadoNaArte do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:molde) { create(:molde, partes: [ lateral ]) }

  it "takes direito, esquerdo or nothing, naming a wrong value" do
    expect(build(:arquivo, lado: "esquerdo")).to be_valid
    expect(build(:arquivo, lado: nil)).to be_valid
    errado = build(:arquivo, lado: "ESQ")
    expect(errado).not_to be_valid
    expect(errado.errors[:lado].first).to include("ESQ is not a side")
  end

  it "abbreviates the side the way the team writes it" do
    expect([ build(:arquivo, lado: "direito").lado_abreviado, build(:arquivo, lado: "esquerdo").lado_abreviado, build(:arquivo).lado_abreviado ]).to eq([ "DIR", "ESQ", nil ])
  end

  it "knows whether the file's part is mirrored in its molde" do
    arquivo = create(:arquivo, molde: molde, peca: lateral)
    expect(arquivo.parte_espelhada?).to be false
    molde.molde_pecas.find_by(peca: lateral).update!(espelhada: true)
    expect(arquivo.parte_espelhada?).to be true
  end

  it "ends the full name with the side" do
    arquivo = create(:arquivo, molde: molde, peca: lateral, nome: "Bluey", lado: "esquerdo")
    expect(arquivo.nome_completo).to end_with("_Bluey_Lateral_ESQ")
  end

  # Without it, the right and left files of a size were offered as "the same
  # arte uploaded again" (one would be merged into the other as a version).
  it "never takes the other side's file of the same size for the same arte uploaded again" do
    corte = create(:arquivo, :corte, peca: lateral)
    trinta = create(:tamanho, arquivo: corte, nome: "29-30")
    direito = create(:arquivo, molde: molde, peca: lateral, tamanho: trinta, nome: "Bluey", lado: "direito")
    esquerdo = create(:arquivo, molde: molde, peca: lateral, tamanho: trinta, nome: "Bluey", lado: "esquerdo")
    outro_direito = create(:arquivo, molde: molde, peca: lateral, tamanho: trinta, nome: "Bluey", lado: "direito")
    expect([ esquerdo.artes_com_mesmo_nome.to_a, outro_direito.artes_com_mesmo_nome.to_a ]).to eq([ [], [ direito ] ])
  end
end
