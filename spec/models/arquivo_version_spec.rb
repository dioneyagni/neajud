require "rails_helper"

RSpec.describe ArquivoVersion, type: :model do
  subject(:version) { build(:arquivo_version) }

  describe "validations" do
    it { should validate_presence_of(:version_number) }
    it { should validate_uniqueness_of(:version_number).scoped_to(:arquivo_id) }
    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:extension) }
    it { should validate_presence_of(:mime_type) }
    it { should validate_presence_of(:original_file) }
    it { should validate_presence_of(:status) }
  end

  describe "associations" do
    it { should belong_to(:arquivo) }
    it { should have_one(:image_metadata).dependent(:destroy) }
    it { should have_many(:cut_layers).dependent(:destroy) }
  end

  describe "callbacks" do
    it "generates uuid before create" do
      version.save!
      expect(version.uuid).to be_present
      expect(version.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "does not overwrite existing uuid" do
      version.uuid = "550e8400-e29b-41d4-a716-446655440000"
      version.save!
      expect(version.uuid).to eq("550e8400-e29b-41d4-a716-446655440000")
    end
  end

  describe "scope .approved_first" do
    let!(:arquivo) { create(:arquivo) }
    let!(:v1) { create(:arquivo_version, arquivo: arquivo, version_number: 1, approved: false) }
    let!(:v2) { create(:arquivo_version, arquivo: arquivo, version_number: 2, approved: true) }
    let!(:v3) { create(:arquivo_version, arquivo: arquivo, version_number: 3, approved: false) }

    it "orders by approved desc then version_number desc" do
      result = arquivo.arquivo_versions.approved_first
      expect(result).to eq([ v2, v3, v1 ])
    end
  end

  describe "#to_param" do
    it "returns uuid" do
      version.save!
      expect(version.to_param).to eq(version.uuid)
    end
  end

  describe "#storage_dir" do
    it "returns the correct storage directory path" do
      version.save!
      expected = Rails.root.join("storage", "stamps", version.arquivo.uuid, "v#{version.version_number}").to_s
      expect(version.storage_dir).to eq(expected)
    end
  end

  describe "#original_path" do
    it "returns the full path to the original file" do
      version.save!
      expected = File.join(version.storage_dir, "original", version.original_file)
      expect(version.original_path).to eq(expected)
    end
  end

  describe "#preview_path" do
    it "returns preview_file when present" do
      version.preview_file = "/some/path/preview.png"
      expect(version.preview_path).to eq("/some/path/preview.png")
    end

    it "returns nil when preview_file is blank" do
      version.preview_file = nil
      expect(version.preview_path).to be_nil
    end

    it "returns nil when preview_file is empty string" do
      version.preview_file = ""
      expect(version.preview_path).to be_nil
    end
  end
end
