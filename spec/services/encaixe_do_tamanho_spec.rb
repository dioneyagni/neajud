require "rails_helper"

# Etapa 2.2 (1/3, decided 07/10/2026): meters of roll per piece, from a simple
# nesting of the size's DXF (bin/encaixe-dxf.js), kept per width.
RSpec.describe EncaixeDoTamanho do
  let(:corte) { create(:arquivo, :corte, extension: "dxf") }
  let(:version) { create(:arquivo_version, arquivo: corte, approved: true, extension: "dxf") }
  let(:tamanho) { create(:tamanho, arquivo: corte, nome: "29-30", position: 1) }

  before { corte.update!(approved_version_id: version.id) }
  after { FileUtils.rm_rf(version.storage_dir) }

  # A closed polyline in mm (the DXF's Y runs along the roll).
  def desenhar(*pontos)
    vertices = pontos.map { |x, y| "10\n#{x}\n20\n#{y}\n" }.join
    caminho = tamanho.dxf_extraido_path(version)
    FileUtils.mkdir_p(File.dirname(caminho))
    File.write(caminho, "0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n4\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n0\nLWPOLYLINE\n8\n0\n90\n#{pontos.size}\n70\n1\n#{vertices}0\nENDSEC\n0\nEOF\n")
  end

  it "fits copies of a square across the roll: 14 of 100 mm on 1,40 m" do
    desenhar([ 0, 0 ], [ 100, 0 ], [ 100, 100 ], [ 0, 100 ])
    expect(described_class.call(tamanho, 1400)).to be_within(0.0002).of(0.1 / 14)
    expect(tamanho.reload.metros_por_peca).to eq("1400" => described_class.call(tamanho, 1400))
  end

  # The point of turning 180°: a right triangle and its turn make a square.
  it "turns a piece 180° to fit it into the previous one" do
    desenhar([ 0, 0 ], [ 100, 0 ], [ 0, 100 ])
    expect(described_class.call(tamanho, 1400)).to be < 0.1 / 14 * 0.7
  end

  it "keeps a width already computed without running Node again" do
    tamanho.update!(metros_por_peca: { "1400" => 0.0123 })
    expect(Open3).not_to receive(:capture3)
    expect(described_class.call(tamanho, 1400)).to eq(0.0123)
  end

  it "is nil for a piece wider than the roll, and while the size's DXF isn't extracted" do
    desenhar([ 0, 0 ], [ 1500, 0 ], [ 1500, 100 ], [ 0, 100 ])
    expect(described_class.call(tamanho, 1400)).to be_nil
    expect(described_class.call(create(:tamanho, arquivo: corte, position: 2), 1400)).to be_nil
  end
end
