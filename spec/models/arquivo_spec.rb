require "rails_helper"

RSpec.describe Arquivo, type: :model do
  subject(:arquivo) { build(:arquivo) }

  describe "validations" do
    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:extension) }
    it { should validate_presence_of(:mime_type) }
  end

  describe "associations" do
    it { should have_many(:arquivo_time_logs).dependent(:destroy) }
    it { should have_many(:arquivo_versions) }
    it { should belong_to(:client).optional }
    it { should belong_to(:molde).optional }
    it { should belong_to(:peca).optional }
    it { should belong_to(:modelo).optional }
    it { should belong_to(:tamanho).optional }
  end

  describe "statuses" do
    it "defines status enum with correct values" do
      expect(Arquivo.statuses).to eq({
        "pending" => "pending",
        "processing" => "processing",
        "processed" => "processed",
        "failed" => "failed",
        "invalid_colorspace" => "invalid_colorspace",
        "unsupported_format" => "unsupported_format"
      })
    end
  end

  describe "callbacks" do
    it "generates uuid before create" do
      arquivo.save!
      expect(arquivo.uuid).to be_present
      expect(arquivo.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "SUPPORTED_EXTENSIONS" do
    it "includes all Artes formats" do
      artes = %w[tif tiff psd ai eps cdr pdf]
      expect(Arquivo::SUPPORTED_EXTENSIONS).to include(*artes)
    end

    it "includes all Corte formats" do
      corte = %w[dxf svg dwg cad]
      expect(Arquivo::SUPPORTED_EXTENSIONS).to include(*corte)
    end

    it "does not include removed formats" do
      expect(Arquivo::SUPPORTED_EXTENSIONS).not_to include("jpg", "jpeg")
    end
  end
end
