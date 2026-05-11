require "rails_helper"

RSpec.describe Stamp, type: :model do
  subject(:stamp) { build(:stamp) }

  describe "validations" do
    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:extension) }
    it { should validate_presence_of(:mime_type) }
    it { should validate_presence_of(:status) }
  end

  describe "associations" do
    it { should have_many(:stamp_time_logs).dependent(:destroy) }
  end

  describe "enums" do
    it "defines status enum with correct values" do
      expect(Stamp.statuses).to eq({
        "pending" => "pending",
        "processing" => "processing",
        "processed" => "processed",
        "failed" => "failed",
        "invalid_colorspace" => "invalid_colorspace",
        "unsupported_format" => "unsupported_format"
      })
    end

    it "defaults to pending" do
      stamp = Stamp.new
      expect(stamp.status).to eq("pending")
    end
  end

  describe "callbacks" do
    it "generates uuid before create" do
      stamp.save!
      expect(stamp.uuid).to be_present
      expect(stamp.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "SUPPORTED_EXTENSIONS" do
    it "includes all required formats" do
      expect(Stamp::SUPPORTED_EXTENSIONS).to match_array(%w[tif tiff psd jpg jpeg ai eps cdr])
    end
  end
end
