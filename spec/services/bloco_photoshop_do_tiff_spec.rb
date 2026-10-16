require "rails_helper"

# Etapa 2.6b2: tiffcrop drops the TIFF's Photoshop block, where the spot
# channels' names live; it is copied back byte for byte.
RSpec.describe BlocoPhotoshopDoTiff do
  let(:pasta) { Dir.mktmpdir }
  let(:tiff) { Rails.root.join("spec/fixtures/files/01.tif").to_s }

  after { FileUtils.rm_rf(pasta) }

  def bloco(arquivo) = described_class::Tiff.new(File.binread(arquivo)).valor(described_class::TAG)

  it "copies the block onto a TIFF that lost it, which stays readable" do
    girada = File.join(pasta, "girada.tif")
    system("tiffcrop", "-R", "90", tiff, girada, err: File::NULL)
    expect(bloco(girada)).to be_nil
    expect(described_class.copiar(tiff, girada)).to be(true)
    expect(bloco(girada)).to eq(bloco(tiff))
    expect(system("tiffinfo", girada, out: File::NULL, err: File::NULL)).to be(true)
  end

  it "replaces a block already there, and keeps the directories after the first" do
    destino = File.join(pasta, "dois.tif")
    system("tiffcp", tiff, tiff, destino, err: File::NULL)
    expect(described_class.copiar(tiff, destino)).to be(true)
    expect(`tiffinfo #{Shellwords.escape(destino)} 2>/dev/null`.scan("TIFF Directory").size).to eq(2)
    expect(bloco(destino)).to eq(bloco(tiff))
  end

  it "does nothing when the original has no block" do
    sem_bloco = File.join(pasta, "sem.tif")
    system("convert", "-size", "4x4", "xc:white", sem_bloco)
    expect(described_class.copiar(sem_bloco, sem_bloco)).to be(false)
  end

  it "refuses what is not a classic TIFF, saying what it expected" do
    png = File.join(pasta, "p.png")
    system("convert", "-size", "4x4", "xc:white", png)
    expect { described_class.copiar(png, png) }.to raise_error(described_class::Invalido, /not a classic TIFF: header .*expected II\*\\0 or MM\\0\*/)
  end
end
