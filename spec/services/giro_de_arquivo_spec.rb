require "rails_helper"

# Etapa 2.6b2 (D4.1, decided 15/10/2026): the DTF file turned 90° for the RIP
# keeps every channel — ImageMagick 6 dropped one of two spot channels (the
# white) — and the spots' names. Real tools on a real CMYK + 2 spots TIFF.
RSpec.describe GiroDeArquivo do
  let(:pasta) { Dir.mktmpdir }
  let(:tiff) { Rails.root.join("spec/fixtures/files/01.tif").to_s }

  after { FileUtils.rm_rf(pasta) }

  def exif(arquivo, *tags)
    tags.map { |tag| `exiftool -s3 -#{tag} #{Shellwords.escape(arquivo)}`.strip }
  end

  # Every sample of every channel, decoded and uncompressed, as libtiff reads it.
  def amostras(arquivo)
    plano = File.join(pasta, "plano-#{SecureRandom.hex(4)}.tif")
    system("tiffcp", "-c", "none", "-r", "100000", "#{arquivo},0", plano, err: File::NULL)
    `tiffinfo -d #{Shellwords.escape(plano)} 2>/dev/null`[/Strip 0:.*/m]
  end

  it "turns a TIFF keeping its channels, the spots' names and the DPI" do
    girada = File.join(pasta, "dtf", "girada.tif")
    described_class.new.girar(tiff, girada)
    expect(exif(girada, "ImageWidth", "ImageHeight", "SamplesPerPixel", "AlphaChannelsNames", "XResolution", "Compression"))
      .to eq([ "486", "609", "6", "Spot_1, Spot_2", "300", "LZW" ])
    expect(Dir.children(File.dirname(girada))).to eq([ "girada.tif" ])
  end

  it "turns it without changing a sample: back 270° it is the original" do
    girada = File.join(pasta, "girada.tif")
    described_class.new.girar(tiff, girada)
    de_volta = File.join(pasta, "volta.tif")
    system("tiffcrop", "-R", "270", girada, de_volta, err: File::NULL)
    expect(amostras(de_volta)).to be_present
    expect(amostras(de_volta)).to eq(amostras(tiff))
  end

  it "turns a PNG with ImageMagick" do
    png = File.join(pasta, "P.png")
    system("convert", "-size", "30x10", "xc:red", png)
    described_class.new.girar(png, File.join(pasta, "girada.png"))
    expect(`identify -format '%wx%h\\n' #{Shellwords.escape(File.join(pasta, "girada.png"))}`.strip).to eq("10x30")
  end

  it "says which formats it turns, and refuses the others naming them" do
    expect(%w[P.TIF P.tiff P.png P.psd P.pdf].map { |nome| described_class.gira?(nome) }).to eq([ true, true, true, false, false ])
    expect { described_class.new.girar("/x/P.psd", File.join(pasta, "g.psd")) }
      .to raise_error(described_class::Falhou, "can't turn \"P.psd\": expected one of .tif, .tiff, .png")
  end

  it "fails naming the file when the tool can't read it, leaving nothing half-written" do
    quebrado = File.join(pasta, "quebrado.tif")
    File.write(quebrado, "not a tiff")
    expect { described_class.new.girar(quebrado, File.join(pasta, "g", "girada.tif")) }
      .to raise_error(described_class::Falhou, "tiffcrop failed turning \"quebrado.tif\"")
    expect(Dir.children(File.join(pasta, "g"))).to be_empty
  end
end
