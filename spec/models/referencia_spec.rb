require "rails_helper"

RSpec.describe Referencia do
  let(:molde) { create(:molde) }

  it "is unique per molde ignoring case and accents, but repeats across moldes" do
    create(:referencia, molde: molde, nome: "Elite")
    duplicada = build(:referencia, molde: molde, nome: "ÉLITE")
    expect(duplicada).not_to be_valid
    expect(duplicada.errors[:nome].first).to include("\"ÉLITE\" already exists in this molde")
    expect(build(:referencia, molde: create(:molde), nome: "Elite")).to be_valid
  end

  describe ".do_molde!" do
    it "finds the molde's referência by its comparable name, or creates it" do
      elite = create(:referencia, molde: molde, nome: "Elite")
      expect(described_class.do_molde!(molde, "elite")).to eq(elite)
      expect { described_class.do_molde!(molde, " Fuel ") }.to change(molde.referencias, :count).by(1)
      expect(molde.referencias.reload.map(&:nome)).to eq(%w[Elite Fuel])
    end
  end
end
