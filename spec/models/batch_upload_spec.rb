require "rails_helper"

RSpec.describe BatchUpload, type: :model do
  subject(:batch) { build(:batch_upload) }

  describe "callbacks" do
    it "generates uuid before create" do
      batch.save!
      expect(batch.uuid).to be_present
      expect(batch.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "defaults" do
    it "defaults counters to 0" do
      batch = BatchUpload.new
      expect(batch.total_files).to eq(0)
      expect(batch.processed_files).to eq(0)
      expect(batch.failed_files).to eq(0)
    end
  end
end
