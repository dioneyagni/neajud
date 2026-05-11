require "rails_helper"

RSpec.describe StampTimeLog, type: :model do
  subject(:log) { build(:stamp_time_log) }

  describe "validations" do
    it { should validate_presence_of(:previous_seconds) }
    it { should validate_presence_of(:new_seconds) }
  end

  describe "associations" do
    it { should belong_to(:stamp) }
  end

  describe "callbacks" do
    it "generates uuid before create" do
      stamp = create(:stamp)
      log = create(:stamp_time_log, stamp: stamp)
      expect(log.uuid).to be_present
      expect(log.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end
end