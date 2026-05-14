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
end
