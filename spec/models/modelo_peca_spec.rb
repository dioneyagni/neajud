require "rails_helper"

RSpec.describe ModeloPeca, type: :model do
  describe "associations" do
    it { should belong_to(:modelo) }
    it { should belong_to(:peca) }
  end

  describe "validations" do
    it "enforces unique peca per modelo" do
      modelo = create(:modelo)
      peca = create(:peca)
      create(:modelo_peca, modelo: modelo, peca: peca)

      duplicate = build(:modelo_peca, modelo: modelo, peca: peca)
      expect(duplicate).not_to be_valid
    end

    it "allows same peca for different modelos" do
      peca = create(:peca)
      modelo1 = create(:modelo)
      modelo2 = create(:modelo)

      create(:modelo_peca, modelo: modelo1, peca: peca)
      mp2 = build(:modelo_peca, modelo: modelo2, peca: peca)
      expect(mp2).to be_valid
    end
  end

  describe "defaults" do
    it "sets needs_cut to true" do
      mp = create(:modelo_peca)
      expect(mp.needs_cut).to be true
    end
  end
end
