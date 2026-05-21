require "rails_helper"

RSpec.describe "DXF tamanho extraction script" do
  let(:script_path) { Rails.root.join("bin", "extract-tamanho-dxf.js").to_s }

  def run_script(input_path, output_path, position)
    system("node", script_path, input_path.to_s, output_path.to_s, position.to_s,
      out: File::NULL, err: File::NULL)
  end

  it "extracts SPLINE-based DXF (CABEDAL fixture)" do
    Dir.mktmpdir do |dir|
      input = Rails.root.join("spec/fixtures/files/CABEDAL - 35 AO 43.dxf").to_s
      output = File.join(dir, "pos1.dxf")
      expect(run_script(input, output, 1)).to be true
      expect(File.size(output)).to be > 0
    end
  end

  it "extracts INSERT-based DXF (36 ao 48 fixture) for all positions" do
    Dir.mktmpdir do |dir|
      input = Rails.root.join("spec/fixtures/files/36 ao 48.dxf").to_s
      (1..7).each do |pos|
        output = File.join(dir, "pos#{pos}.dxf")
        expect(run_script(input, output, pos)).to be true
        expect(File.size(output)).to be > 0
      end
    end
  end

  it "extracts single-tamanho DXF (29-30 fixture)" do
    Dir.mktmpdir do |dir|
      input = Rails.root.join("spec/fixtures/files/29-30.dxf").to_s
      output = File.join(dir, "pos1.dxf")
      expect(run_script(input, output, 1)).to be true
      expect(File.size(output)).to be > 0
    end
  end

  it "fails when position is out of range" do
    Dir.mktmpdir do |dir|
      input = Rails.root.join("spec/fixtures/files/29-30.dxf").to_s
      output = File.join(dir, "out.dxf")
      expect(run_script(input, output, 99)).to be false
    end
  end

  it "fails when position out of range for INSERT-based DXF" do
    Dir.mktmpdir do |dir|
      input = Rails.root.join("spec/fixtures/files/36 ao 48.dxf").to_s
      output = File.join(dir, "out.dxf")
      expect(run_script(input, output, 99)).to be false
    end
  end
end
