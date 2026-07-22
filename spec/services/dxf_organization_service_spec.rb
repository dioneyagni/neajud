require "rails_helper"

RSpec.describe DxfOrganizationService do
  let(:dxf_arquivo) { create(:arquivo, :corte, filename: "test_design") }
  let(:version) { create(:arquivo_version, arquivo: dxf_arquivo, approved: true, status: "processed") }
  let(:service) { described_class.new(dxf_arquivo) }

  before do
    dxf_arquivo.update!(approved_version: version)
    FileUtils.mkdir_p(version.storage_dir)
  end

  describe ".call" do
    it "skips non-DXF files" do
      tif = create(:arquivo, extension: "tif")
      expect(described_class.call(tif)).to be_nil
    end

    it "skips when no approved version exists" do
      dxf_arquivo.update!(approved_version: nil)
      expect(described_class.call(dxf_arquivo)).to be_nil
    end

    it "skips when original file does not exist" do
      expect(described_class.call(dxf_arquivo)).to be_nil
    end
  end

  describe "tamanho detection" do
    let(:detect_output) do
      {
        "tamanhos" => [
          {
            "nome" => "P",
            "position" => 1,
            "width_mm" => 120.0,
            "height_mm" => 80.0,
            "area_mm2" => 9600.0,
            "perimeter_mm" => 400.0,
            "inner_lines_mm" => 0.0,
            "total_line_mm" => 400.0,
            "color" => "FF0000"
          }
        ],
        "overlaps" => []
      }
    end

    before do
      original_path = version.original_path
      FileUtils.mkdir_p(File.dirname(original_path))
      FileUtils.touch(original_path)

      allow(service).to receive(:`).and_return(detect_output.to_json)

      # Stub the preview generation to avoid actual shell/file operations
      allow(service).to receive(:generate_tamanho_preview)
    end

    it "creates tamanho records from Node.js output" do
      expect {
        service.call
      }.to change(Tamanho, :count).by(1)

      tamanho = Tamanho.last
      expect(tamanho.nome).to eq("P")
      expect(tamanho.position).to eq(1)
      expect(tamanho.width_mm).to eq(120.0)
      expect(tamanho.height_mm).to eq(80.0)
    end

    it "sets organize_error to nil on success" do
      service.call
      expect(dxf_arquivo.reload.organize_error).to be_nil
    end

    it "does nothing when no tamanhos detected" do
      allow(service).to receive(:`).and_return({ "tamanhos" => [] }.to_json)

      expect {
        service.call
      }.not_to change(Tamanho, :count)
    end

    it "does nothing when output is blank" do
      allow(service).to receive(:`).and_return("")

      expect {
        service.call
      }.not_to change(Tamanho, :count)
    end

    it "handles invalid JSON from Node.js gracefully" do
      allow(service).to receive(:`).and_return("not valid json {{{")

      expect {
        service.call
      }.not_to raise_error
      expect(Tamanho.count).to eq(0)
    end
  end

  describe "overlap handling" do
    let(:tamanho_data) do
      [
        { "nome" => "P", "position" => 1, "width_mm" => 120.0, "height_mm" => 80.0,
          "area_mm2" => 9600.0, "perimeter_mm" => 400.0, "inner_lines_mm" => 0.0,
          "total_line_mm" => 400.0, "color" => "FF0000" },
        { "nome" => "M", "position" => 2, "width_mm" => 150.0, "height_mm" => 100.0,
          "area_mm2" => 15000.0, "perimeter_mm" => 500.0, "inner_lines_mm" => 0.0,
          "total_line_mm" => 500.0, "color" => "00FF00" }
      ]
    end

    before do
      original_path = version.original_path
      FileUtils.mkdir_p(File.dirname(original_path))
      FileUtils.touch(original_path)

      allow(service).to receive(:generate_tamanho_preview)
    end

    it "sets organize_error when unresolved overlaps exist" do
      detect_output = {
        "tamanhos" => tamanho_data,
        "overlaps" => [
          { "color_a" => "FF0000", "color_b" => "00FF00" }
        ]
      }
      allow(service).to receive(:`).and_return(detect_output.to_json)

      # No cut layers with hole annotation, so overlaps remain unresolved
      service.call
      expect(dxf_arquivo.reload.organize_error).to eq(DxfOrganizationService::OVERLAP_ERROR)
    end

    it "resolves overlaps involving hole colors" do
      # Create a cut layer with hole annotation
      CutLayer.create!(
        arquivo_version: version,
        layer_name: "Cut Layer",
        annotation: "hole",
        color: "FF0000"
      )

      detect_output = {
        "tamanhos" => tamanho_data,
        "overlaps" => [
          { "color_a" => "FF0000", "color_b" => "00FF00" }
        ]
      }
      allow(service).to receive(:`).and_return(detect_output.to_json)

      service.call
      expect(dxf_arquivo.reload.organize_error).to be_nil
    end
  end
end
