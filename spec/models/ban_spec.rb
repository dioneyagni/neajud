require "rails_helper"

RSpec.describe Ban, type: :model do
  subject(:ban) { build(:ban) }

  describe "validations" do
    it { should validate_presence_of(:ip_address) }
  end

  describe "callbacks" do
    it "generates uuid before create" do
      ban.save!
      expect(ban.uuid).to be_present
      expect(ban.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "#active?" do
    it "returns true when expires_at is nil" do
      ban = build(:ban, expires_at: nil)
      expect(ban).to be_active
    end

    it "returns true when expires_at is in the future" do
      ban = build(:ban, expires_at: 1.hour.from_now)
      expect(ban).to be_active
    end

    it "returns false when expires_at is in the past" do
      ban = build(:ban, expires_at: 1.hour.ago)
      expect(ban).not_to be_active
    end
  end

  describe "scope .active" do
    it "includes bans without expiration" do
      ban = create(:ban, expires_at: nil)
      expect(Ban.active).to include(ban)
    end

    it "excludes expired bans" do
      ban = create(:ban, expires_at: 1.hour.ago)
      expect(Ban.active).not_to include(ban)
    end
  end
end
