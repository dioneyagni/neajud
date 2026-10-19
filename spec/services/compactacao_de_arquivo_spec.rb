require "rails_helper"

# Etapa 2.7c (decided 19/10/2026): a corrida's or cor lisa's TIFF compacted
# for the RIP with tiffcp — the spot channels and their names kept.
RSpec.describe CompactacaoDeArquivo do
  let(:pasta) { Dir.mktmpdir }
  let(:destino) { File.join(pasta, "tecido", "compactado.tif") }

  after { FileUtils.rm_rf(pasta) }

  def spots(caminho)
    `exiftool -s3 -AlphaChannelsNames #{Shellwords.escape(caminho)} 2>/dev/null`.strip
  end

  # tiffcp alone dropped the Photoshop block: "Spot_1, Spot_2" came out unnamed.
  it "compacts a TIFF smaller, keeping its spot channels' names" do
    origem = Rails.root.join("spec/fixtures/files/01.tif").to_s
    described_class.new.compactar(origem, destino)
    expect(File.size(destino)).to be < File.size(origem)
    expect(spots(destino)).to eq("Spot_1, Spot_2")
    expect(`identify -format '%w %h %[channels]\\n' #{Shellwords.escape(destino)}[0] 2>/dev/null`).to eq(`identify -format '%w %h %[channels]\\n' #{Shellwords.escape(origem)}[0] 2>/dev/null`)
    expect(Dir.children(File.dirname(destino))).to eq([ "compactado.tif" ])
  end

  it "refuses a result not smaller, leaving nothing behind" do
    origem = File.join(pasta, "ruido.tif")
    system("convert", "-size", "64x64", "xc:", "+noise", "Random", "-depth", "8", "-compress", "none", origem, exception: true)
    expect { described_class.new.compactar(origem, destino) }.to raise_error(described_class::Falhou, /ruido.tif" compacted to \d+ bytes, not smaller than its \d+/)
    expect(File.exist?(File.dirname(destino)) ? Dir.children(File.dirname(destino)) : []).to be_empty
  end

  it "compacts only TIFFs" do
    expect([ described_class.compacta?("CR-1.TIF"), described_class.compacta?("CR-1.tiff"), described_class.compacta?("CR-1.psd") ]).to eq([ true, true, false ])
    expect { described_class.new.compactar(Rails.root.join("spec/fixtures/files/01-no_spot.psd").to_s, destino) }
      .to raise_error(described_class::Falhou, /can't compact "01-no_spot.psd": expected an existing file ending in .tif, .tiff/)
  end
end
