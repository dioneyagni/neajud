require "rails_helper"

RSpec.describe Empresa do
  it "allows only one empresa per instance and names the existing one" do
    create(:empresa, nome: "Sublimação X")
    segunda = build(:empresa, nome: "Outra")
    expect(segunda).not_to be_valid
    expect(segunda.errors[:base].first).to include("Sublimação X", "at most one")
  end

  it ".atual is the instance's empresa, nil before setup" do
    expect(Empresa.atual).to be_nil
    empresa = create(:empresa)
    expect(Empresa.atual).to eq(empresa)
  end

  # Etapa 2.2 (1/3): the dono's production parameters.
  it "starts with a 1,60 m paper and a band of -10% / +25%, refusing nonsense" do
    empresa = Empresa.atual || create(:empresa)
    expect(empresa.attributes.values_at("largura_papel_mm", "tolerancia_abaixo_pct", "tolerancia_acima_pct")).to eq([ 1600, 10, 25 ])
    empresa.assign_attributes(largura_papel_mm: 0, tolerancia_abaixo_pct: 101)
    expect(empresa).not_to be_valid
    expect(empresa.errors.attribute_names).to contain_exactly(:largura_papel_mm, :tolerancia_abaixo_pct)
  end

  # Etapa 2.3: the paper is a material; its width replaces the typed one.
  it "fits the artes on the default paper's width, else the typed one, and takes only a papel as default" do
    empresa = Empresa.atual || create(:empresa)
    expect(empresa.largura_papel_efetiva_mm).to eq(1600)
    papel = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Papel"), cor_material: CorMaterial.create!(nome: "Branco"), largura: "1,10 m", gramatura: "40g", tipo: "papel")
    empresa.update!(papel_padrao: papel)
    expect(empresa.largura_papel_efetiva_mm).to eq(1100)
    papel.update!(tipo: "tecido")
    expect(empresa.reload).not_to be_valid
    expect(empresa.errors[:papel_padrao].first).to include("is a tecido; expected a material of type papel")
  end
end
