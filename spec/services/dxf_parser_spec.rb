require "rails_helper"

RSpec.describe StampProcessingJob do
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
      stamp = create(:stamp, extension: "dxf", category: "corte")
      version = create(:stamp_version, stamp: stamp, version_number: 1, extension: "dxf")

      dir = File.join(Rails.root, "storage", "stamps", stamp.uuid, "v1", "original")
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

      FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", stamp.uuid))
      File.delete(svg_out) if File.exist?(svg_out)
      stamp.destroy!
    end

    it "returns no measurements when there are no cut layers" do
      stamp = create(:stamp, extension: "dxf", category: "corte")
      version = create(:stamp_version, stamp: stamp, version_number: 1, extension: "dxf")
      expect { DxfMeasurementService.call(version) }.not_to raise_error
      stamp.destroy!
    end
  end
end
