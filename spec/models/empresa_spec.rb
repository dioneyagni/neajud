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
end
