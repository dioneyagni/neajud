require "rails_helper"

RSpec.describe FileCategory do
  describe ".all" do
    it "returns the categories hash" do
      expect(described_class.all).to have_key("artes")
      expect(described_class.all).to have_key("corte")
    end
  end

  describe ".keys" do
    it "returns category names" do
      expect(described_class.keys).to contain_exactly("artes", "corte")
    end
  end

  describe ".extensions" do
    it "returns all extensions without duplicates" do
      exts = described_class.extensions
      expect(exts).to include("tif", "psd", "svg", "dxf")
      expect(exts).not_to include("jpg", "jpeg")
      expect(exts.uniq).to eq(exts)
    end
  end

  describe ".for_extension" do
    it "returns 'artes' for TIFF" do
      expect(described_class.for_extension("tif")).to eq("artes")
      expect(described_class.for_extension("TIFF")).to eq("artes")
    end

    it "returns 'artes' for PSD" do
      expect(described_class.for_extension("psd")).to eq("artes")
    end

    it "returns 'corte' for SVG" do
      expect(described_class.for_extension("svg")).to eq("corte")
    end

    it "returns 'corte' for DXF" do
      expect(described_class.for_extension("dxf")).to eq("corte")
    end

    it "returns nil for unsupported extension" do
      expect(described_class.for_extension("png")).to be_nil
      expect(described_class.for_extension("jpg")).to be_nil
    end
  end

  describe ".preview_enabled?" do
    it "returns true for artes" do
      expect(described_class.preview_enabled?("artes")).to be true
    end

    it "returns false for corte" do
      expect(described_class.preview_enabled?("corte")).to be false
    end

    it "returns true for unknown category" do
      expect(described_class.preview_enabled?(nil)).to be true
      expect(described_class.preview_enabled?("unknown")).to be true
    end
  end

  describe ".spot_detection_enabled?" do
    it "returns true for artes" do
      expect(described_class.spot_detection_enabled?("artes")).to be true
    end

    it "returns false for corte" do
      expect(described_class.spot_detection_enabled?("corte")).to be false
    end

    it "returns false for unknown category" do
      expect(described_class.spot_detection_enabled?(nil)).to be false
    end
  end

  describe ".notes" do
    it "returns notes for PDF in artes" do
      expect(described_class.notes("pdf", "artes")).to eq("PDF for print")
    end

    it "returns notes for PDF in corte" do
      expect(described_class.notes("pdf", "corte")).to eq("PDF with cut vectors")
    end

    it "returns empty string when no notes exist" do
      expect(described_class.notes("tif", "artes")).to eq("")
    end
  end
end
