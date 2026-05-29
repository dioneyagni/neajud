require "rails_helper"

RSpec.describe ArquivoProcessingJob do
  describe "#extract_colors_from_svg" do
    it "extracts hex stroke colors from drawing groups" do
      svg = <<~SVG
        <svg><g stroke="#000000" stroke-width="0.1%">
          <g stroke="#FF0000"><g><path d="M0 0"/></g></g>
        </g></svg>
      SVG
      file = Tempfile.new([ "test", ".svg" ])
      file.write(svg)
      file.close
      colors = described_class.new.send(:extract_colors_from_svg, file.path)
      expect(colors).to eq([ "#FF0000" ])
      file.unlink
    end

    it "extracts rgb() stroke colors and ignores container stroke" do
      svg = <<~SVG
        <svg><g stroke="#000000" stroke-width="0.1%">
          <g stroke="rgb(0, 255, 0)"><g><path d="M0 0"/></g></g>
        </g></svg>
      SVG
      file = Tempfile.new([ "test", ".svg" ])
      file.write(svg)
      file.close
      colors = described_class.new.send(:extract_colors_from_svg, file.path)
      expect(colors).to eq([ "#00FF00" ])
      file.unlink
    end

    it "deduplicates colors" do
      svg = <<~SVG
        <svg><g stroke="#000000" stroke-width="0.1%">
          <g stroke="#FF0000"><g><path d="M0 0"/></g></g>
          <g stroke="rgb(255, 0, 0)"><g><path d="M0 0"/></g></g>
          <g stroke="#00FF00"><g><path d="M0 0"/></g></g>
        </g></svg>
      SVG
      file = Tempfile.new([ "test", ".svg" ])
      file.write(svg)
      file.close
      colors = described_class.new.send(:extract_colors_from_svg, file.path)
      expect(colors).to contain_exactly("#FF0000", "#00FF00")
      file.unlink
    end

    it "extracts only colors from REFORÇO DXF SVG preview (no extra #000000)" do
      path = Rails.root.join("spec/fixtures/files/REFORÇO - 35 AO 43.dxf").to_s
      out = Rails.root.join("tmp", "test-ref-svg.svg").to_s
      system("node", Rails.root.join("bin/generate-dxf-preview.js").to_s, path, out) || raise("SVG generation failed")
      colors = described_class.new.send(:extract_colors_from_svg, out)
      expect(colors).to contain_exactly("#000000", "#FF0000", "#00FF00")
      File.delete(out) if File.exist?(out)
    end

    it "extracts only 1 color from 29-30 DXF SVG preview (no extra container stroke)" do
      path = Rails.root.join("spec/fixtures/files/29-30.dxf").to_s
      out = Rails.root.join("tmp", "test-2930-svg.svg").to_s
      system("node", Rails.root.join("bin/generate-dxf-preview.js").to_s, path, out) || raise("SVG generation failed")
      colors = described_class.new.send(:extract_colors_from_svg, out)
      expect(colors).to contain_exactly("#333333")
      File.delete(out) if File.exist?(out)
    end
  end

  describe "#measure_cut_layers integration" do
    it "measures REFORÇO DXF cut layers by color" do
    arquivo = create(:arquivo, extension: "dxf", category: "corte")
    version = create(:arquivo_version, arquivo: arquivo, version_number: 1, extension: "dxf")

    dir = File.join(Rails.root, "storage", "stamps", arquivo.uuid, "v1", "original")
    FileUtils.mkdir_p(dir)
    src = Rails.root.join("spec/fixtures/files/REFORÇO - 35 AO 43.dxf").to_s
    dest = File.join(dir, "REFORÇO - 35 AO 43.dxf")
    FileUtils.cp(src, dest)
    version.update!(original_file: "REFORÇO - 35 AO 43.dxf")

    svg_out = Rails.root.join("tmp", "test-ref-svg.svg").to_s
    system("node", Rails.root.join("bin/generate-dxf-preview.js").to_s, dest, svg_out) || raise("SVG gen failed")
    version.update!(preview_file: svg_out.to_s)

    described_class.new.send(:extract_cut_layers_from_preview, version)
    DxfMeasurementService.call(version)

    version.reload
    expect(version.cut_layers.count).to eq(3)
    black = version.cut_layers.find_by(color: "#000000")
    expect(black.width_mm).to be_within(0.1).of(2276.6)
    expect(black.height_mm).to be_within(0.1).of(354.1)
    expect(black.perimeter_mm).to be_within(0.1).of(4959.7)
    expect(black.area_mm2).to be_within(0.1).of(326846.9)

    red = version.cut_layers.find_by(color: "#FF0000")
    expect(red.width_mm).to be_within(0.1).of(2144.9)
    expect(red.height_mm).to be_within(0.1).of(177.1)
    expect(red.perimeter_mm).to be_within(0.1).of(5136.8)
    expect(red.area_mm2).to be_within(0.1).of(23759.9)

    green = version.cut_layers.find_by(color: "#00FF00")
    expect(green.width_mm).to be_within(0.1).of(2245.2)
    expect(green.height_mm).to be_within(0.1).of(223.1)

    FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", arquivo.uuid))
    File.delete(svg_out) if File.exist?(svg_out)
    arquivo.destroy!
    end

    it "returns no measurements when there are no cut layers" do
      arquivo = create(:arquivo, extension: "dxf", category: "corte")
      version = create(:arquivo_version, arquivo: arquivo, version_number: 1, extension: "dxf")
      expect { DxfMeasurementService.call(version) }.not_to raise_error
      arquivo.destroy!
    end
  end

  describe "#organize_dxf integration" do
    it "detects 5 tamanhos in CABEDAL DXF" do
      arquivo = create(:arquivo, extension: "dxf", category: "corte", filename: "CABEDAL - 35 AO 43")
      version = create(:arquivo_version, arquivo: arquivo, version_number: 1, extension: "dxf")

      dir = File.join(Rails.root, "storage", "stamps", arquivo.uuid, "v1", "original")
      FileUtils.mkdir_p(dir)
      src = Rails.root.join("spec/fixtures/files/CABEDAL - 35 AO 43.dxf").to_s
      dest = File.join(dir, "CABEDAL - 35 AO 43.dxf")
      FileUtils.cp(src, dest)
      version.update!(original_file: "CABEDAL - 35 AO 43.dxf")

      arquivo.update!(approved_version_id: version.id)
      described_class.new.send(:organize_dxf, version)

      arquivo.reload
      expect(arquivo.tamanhos.count).to eq(5)
      expect(arquivo.tamanhos.first.nome).to eq("35")
      expect(arquivo.tamanhos.first.width_mm).to be_within(0.1).of(254.5)
      expect(arquivo.tamanhos.last.nome).to eq("43")
      expect(arquivo.tamanhos.last.width_mm).to be_within(0.1).of(296.9)
      expect(arquivo.tamanhos.first.perimeter_mm).to be_present
      expect(arquivo.tamanhos.first.total_line_mm).to be_present

      FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", arquivo.uuid))
      arquivo.destroy!
    end

    it "detects 1 tamanho in 29-30 DXF" do
      arquivo = create(:arquivo, extension: "dxf", category: "corte", filename: "29-30")
      version = create(:arquivo_version, arquivo: arquivo, version_number: 1, extension: "dxf")

      dir = File.join(Rails.root, "storage", "stamps", arquivo.uuid, "v1", "original")
      FileUtils.mkdir_p(dir)
      src = Rails.root.join("spec/fixtures/files/29-30.dxf").to_s
      dest = File.join(dir, "29-30.dxf")
      FileUtils.cp(src, dest)
      version.update!(original_file: "29-30.dxf")

      arquivo.update!(approved_version_id: version.id)
      described_class.new.send(:organize_dxf, version)

      arquivo.reload
      expect(arquivo.tamanhos.count).to eq(1)
      expect(arquivo.tamanhos.first.nome).to eq("Size 1")
      expect(arquivo.tamanhos.first.area_mm2).to be_within(0.1).of(31182.9)
      expect(arquivo.tamanhos.first.perimeter_mm).to be_present
      expect(arquivo.tamanhos.first.total_line_mm).to be_present

      FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", arquivo.uuid))
      arquivo.destroy!
    end

    it "detects 5 tamanhos in REFORÇO DXF (not inner lines)" do
      arquivo = create(:arquivo, extension: "dxf", category: "corte", filename: "REFORÇO - 35 AO 43")
      version = create(:arquivo_version, arquivo: arquivo, version_number: 1, extension: "dxf")

      dir = File.join(Rails.root, "storage", "stamps", arquivo.uuid, "v1", "original")
      FileUtils.mkdir_p(dir)
      src = Rails.root.join("spec/fixtures/files/REFORÇO - 35 AO 43.dxf").to_s
      dest = File.join(dir, "REFORÇO - 35 AO 43.dxf")
      FileUtils.cp(src, dest)
      version.update!(original_file: "REFORÇO - 35 AO 43.dxf")

      arquivo.update!(approved_version_id: version.id)
      described_class.new.send(:organize_dxf, version)

      arquivo.reload
      expect(arquivo.tamanhos.count).to eq(5)
      expect(arquivo.tamanhos.first.nome).to eq("35")
      expect(arquivo.tamanhos.last.nome).to eq("43")

      FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", arquivo.uuid))
      arquivo.destroy!
    end

    it "creates arquivo with default organized=false" do
      arquivo = create(:arquivo, extension: "dxf", category: "corte")
      expect(arquivo.organized).to be false
      arquivo.destroy!
    end
  end

  describe "#organize_dxf overlap detection" do
    def write_overlap_dxf(path, color_a: 1, color_b: 3)
      lines = [
        "0", "SECTION",
        "2", "HEADER",
        "9", "$INSUNITS",
        "70", "4",
        "0", "ENDSEC",
        "0", "SECTION",
        "2", "TABLES",
        "0", "TABLE",
        "2", "LAYER",
        "70", "2",
        "0", "LAYER",
        "2", "0",
        "70", "0",
        "62", "7",
        "6", "Continuous",
        "0", "LAYER",
        "2", "Camada 1",
        "70", "0",
        "62", "7",
        "6", "Continuous",
        "0", "ENDTAB",
        "0", "ENDSEC",
        "0", "SECTION",
        "2", "ENTITIES",
        "0", "LWPOLYLINE",
        "8", "0",
        "62", color_a.to_s,
        "90", "4",
        "70", "1",
        "10", "0", "20", "0",
        "10", "100", "20", "0",
        "10", "100", "20", "100",
        "10", "0", "20", "100",
        "0", "LWPOLYLINE",
        "8", "0",
        "62", color_b.to_s,
        "90", "4",
        "70", "1",
        "10", "50", "20", "50",
        "10", "150", "20", "50",
        "10", "150", "20", "150",
        "10", "50", "20", "150",
        "0", "ENDSEC",
        "0", "EOF"
      ]
      File.write(path, lines.join("\n"))
    end

    it "detects overlapping outer polylines and sets organize_error" do
      tmp = Rails.root.join("tmp", "test-overlap.dxf")
      write_overlap_dxf(tmp)

      arquivo = create(:arquivo, extension: "dxf", category: "corte", filename: "overlap")
      version = create(:arquivo_version, arquivo: arquivo, version_number: 1, extension: "dxf",
        original_file: "overlap.dxf")
      dir = File.join(Rails.root, "storage", "stamps", arquivo.uuid, "v1", "original")
      FileUtils.mkdir_p(dir)
      FileUtils.cp(tmp, File.join(dir, "overlap.dxf"))
      arquivo.update!(approved_version_id: version.id)

      described_class.new.send(:organize_dxf, version)

      arquivo.reload
      expect(arquivo.organize_error).to eq(DxfOrganizationService::OVERLAP_ERROR)
      expect(arquivo.tamanhos.count).to eq(2)

      FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", arquivo.uuid))
      File.delete(tmp) if File.exist?(tmp)
      arquivo.destroy!
    end

    it "removes overlapping tamanho when its color is marked as hole in cut_layers" do
      tmp = Rails.root.join("tmp", "test-overlap-hole.dxf")
      write_overlap_dxf(tmp, color_a: 1, color_b: 3)

      arquivo = create(:arquivo, extension: "dxf", category: "corte", filename: "overlap-hole")
      version = create(:arquivo_version, arquivo: arquivo, version_number: 1, extension: "dxf",
        original_file: "overlap-hole.dxf")
      dir = File.join(Rails.root, "storage", "stamps", arquivo.uuid, "v1", "original")
      FileUtils.mkdir_p(dir)
      FileUtils.cp(tmp, File.join(dir, "overlap-hole.dxf"))
      arquivo.update!(approved_version_id: version.id)

      # Generate SVG preview so cut_layers get created with colors
      svg_out = Rails.root.join("tmp", "test-overlap-svg.svg").to_s
      system("node", Rails.root.join("bin/generate-dxf-preview.js").to_s, tmp.to_s, svg_out) || raise("SVG gen failed")
      version.update!(preview_file: svg_out.to_s)

      described_class.new.send(:extract_cut_layers_from_preview, version)
      version.reload
      # Mark the red layer as hole
      red = version.cut_layers.find_by(color: "#FF0000")
      red&.update!(annotation: "hole") if red

      described_class.new.send(:organize_dxf, version)

      arquivo.reload
      expect(arquivo.organize_error).to be_nil
      expect(arquivo.tamanhos.count).to eq(1)

      FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", arquivo.uuid))
      File.delete(tmp) if File.exist?(tmp)
      File.delete(svg_out) if File.exist?(svg_out)
      arquivo.destroy!
    end
  end
end
