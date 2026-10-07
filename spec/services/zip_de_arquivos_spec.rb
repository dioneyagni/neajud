require "rails_helper"

RSpec.describe ZipDeArquivos do
  it "puts each file under its name, contents intact" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "a.dxf"), "SECTION A")
      File.write(File.join(dir, "b.dxf"), "SECTION B")
      dados = described_class.gerar("Lateral 29-30.dxf" => File.join(dir, "a.dxf"), "Lingua 30-31.dxf" => File.join(dir, "b.dxf"))

      lidos = Zip::File.open_buffer(StringIO.new(dados)).entries.to_h { |e| [ e.name, e.get_input_stream.read ] }
      expect(lidos).to eq("Lateral 29-30.dxf" => "SECTION A", "Lingua 30-31.dxf" => "SECTION B")
    end
  end
end
