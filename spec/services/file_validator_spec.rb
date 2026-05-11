require "rails_helper"

RSpec.describe FileValidator do
  let(:tiff_path) { Rails.root.join("tmp", "test-validate.tif") }

  before do
    unless File.exist?(tiff_path)
      system("convert -size 10x10 xc:red -compress none 'TIFF:#{tiff_path}'")
    end
  end

  after do
    File.delete(tiff_path) if File.exist?(tiff_path)
  end

  describe "#real_format" do
    it "detects TIFF format" do
      validator = FileValidator.new(tiff_path.to_s)
      expect(validator.real_format).to eq("TIFF")
    end

    it "returns nil for nonexistent file" do
      validator = FileValidator.new("/nonexistent.tif")
      expect(validator.real_format).to be_nil
    end
  end

  describe "#valid_extension?" do
    it "returns true when extension matches real format" do
      validator = FileValidator.new(tiff_path.to_s)
      expect(validator.valid_extension?("tif")).to be true
      expect(validator.valid_extension?("tiff")).to be true
    end

    it "returns false when extension does not match" do
      validator = FileValidator.new(tiff_path.to_s)
      expect(validator.valid_extension?("jpg")).to be false
      expect(validator.valid_extension?("psd")).to be false
    end

    it "returns false for unsupported extension" do
      validator = FileValidator.new(tiff_path.to_s)
      expect(validator.valid_extension?("docx")).to be false
    end
  end

  describe "supported formats mapping" do
    {
      "tif" => "TIFF", "tiff" => "TIFF",
      "psd" => "PSD",
      "jpg" => "JPEG", "jpeg" => "JPEG",
      "ai" => "PDF",
      "eps" => "EPT",
      "cdr" => "CDR"
    }.each do |ext, fmt|
      it "maps #{ext} to #{fmt}" do
        expect(FileValidator::EXTENSION_TO_FORMAT[ext]).to eq(fmt)
      end
    end
  end
end
