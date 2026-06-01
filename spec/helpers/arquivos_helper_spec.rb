require "rails_helper"

RSpec.describe ArquivosHelper, type: :helper do
  describe "#format_time" do
    it "returns '0:00' for nil" do
      expect(helper.format_time(nil)).to eq("0:00")
    end

    it "returns '0:00' for 0 seconds" do
      expect(helper.format_time(0)).to eq("0:00")
    end

    it "formats seconds as hours:minutes" do
      expect(helper.format_time(3661)).to eq("1:01")
    end

    it "formats less than an hour correctly" do
      expect(helper.format_time(3599)).to eq("0:59")
    end

    it "formats multiple hours correctly" do
      expect(helper.format_time(7200)).to eq("2:00")
    end

    it "pads minutes with leading zero" do
      expect(helper.format_time(3900)).to eq("1:05")
    end
  end

  describe "#format_cm" do
    it "returns nil when pixels is nil" do
      expect(helper.format_cm(nil, 300)).to be_nil
    end

    it "returns nil when dpi is nil" do
      expect(helper.format_cm(1000, nil)).to be_nil
    end

    it "returns nil when dpi is zero" do
      expect(helper.format_cm(1000, 0)).to be_nil
    end

    it "returns nil when dpi is negative" do
      expect(helper.format_cm(1000, -1)).to be_nil
    end

    it "converts pixels to cm" do
      expect(helper.format_cm(300, 300)).to eq("2.5")
    end

    it "rounds to one decimal place" do
      expect(helper.format_cm(100, 300)).to eq("0.8")
    end
  end
end
