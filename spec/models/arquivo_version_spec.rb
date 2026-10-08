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
      expected = ArquivoVersion::STORAGE_BASE.join(version.arquivo.uuid, "v#{version.version_number}").to_s
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

  describe "#store_original!" do
    let(:version) { create(:arquivo_version, version_number: 1) }
    let(:upload) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/02-no_spot.tif"), "image/tiff") }

    after { FileUtils.rm_rf(File.dirname(version.storage_dir)) }

    it "writes the upload byte-for-byte to original/<filename>" do
      version.store_original!(upload)
      stored = File.join(version.storage_dir, "original", "02-no_spot.tif")
      expect(File.binread(stored)).to eq(File.binread(Rails.root.join("spec/fixtures/files/02-no_spot.tif")))
    end

    it "works on an unsaved version (storage_dir needs only arquivo + version_number)" do
      unsaved = build(:arquivo_version, arquivo: version.arquivo, version_number: 2)
      unsaved.store_original!(upload)
      expect(File.exist?(File.join(unsaved.storage_dir, "original", "02-no_spot.tif"))).to be true
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

  # Regression: storage/stamps/ and storage/test_stamps/ used to be the same
  # directory, so bin/e2e's `rm -rf storage/stamps/*` (needed so E2E runs
  # never accumulate test uploads) also destroyed real development uploads.
  describe "STORAGE_BASE" do
    it "resolves under storage/test_stamps/, never storage/stamps/, in the test env" do
      expect(described_class::STORAGE_BASE.to_s).to end_with("/storage/test_stamps")
    end
  end

  # Etapa 2.2 (1/3): the printed rectangle on the paper's roll. A calçado
  # arte never turns (decided 07/10/2026); girar: is for a later type (DTF).
  describe "#metros_por_peca" do
    def com_medidas(width_px, height_px, dpi)
      create(:arquivo_version).tap { |v| ArquivoImageMetadata.create!(arquivo_version: v, width_px: width_px, height_px: height_px, dpi: dpi) }
    end

    it "keeps the file's width across the roll, without turning" do
      # 254 × 50,8 mm on 1600 mm: 6 across → 0,00847 m (turned it would be 0,00819).
      expect(com_medidas(3000, 600, 300).metros_por_peca(1600)).to eq(0.00847)
    end

    it "tries 90° too when asked, keeping the better" do
      expect(com_medidas(3000, 600, 300).metros_por_peca(1600, girar: true)).to eq(0.00819)
    end

    it "is nil without size or DPI, or when it doesn't fit either way" do
      expect(create(:arquivo_version).metros_por_peca(1600)).to be_nil
      expect(com_medidas(3000, 600, nil).metros_por_peca(1600)).to be_nil
      expect(com_medidas(30000, 30000, 300).metros_por_peca(1600)).to be_nil
      # 50,8 × 2540 mm: as it is, 31 across; turned it would not fit at all.
      expect(com_medidas(600, 30000, 300).metros_por_peca(1600)).to eq(0.08194)
    end
  end
end
