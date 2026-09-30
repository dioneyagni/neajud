require "rails_helper"

RSpec.describe MoldePeca, type: :model do
  describe "associations" do
    it { should belong_to(:molde) }
    it { should belong_to(:peca) }
  end

  describe "validations" do
    it "enforces unique peca per molde" do
      molde = create(:molde)
      peca = create(:peca)
      create(:molde_peca, molde: molde, peca: peca)

      duplicate = build(:molde_peca, molde: molde, peca: peca)
      expect(duplicate).not_to be_valid
    end

    it "allows same peca for different moldes" do
      peca = create(:peca)
      molde1 = create(:molde)
      molde2 = create(:molde)

      create(:molde_peca, molde: molde1, peca: peca)
      mp2 = build(:molde_peca, molde: molde2, peca: peca)
      expect(mp2).to be_valid
    end
  end

  describe "defaults" do
    it "sets needs_cut to true" do
      mp = create(:molde_peca)
      expect(mp.needs_cut).to be true
    end
  end
end
