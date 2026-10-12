require "rails_helper"

# Etapa 2.5b: the real ImageMagick, on solid-color files made here.
RSpec.describe MedidaDeCor do
  let(:pasta) { Dir.mktmpdir }

  after { FileUtils.rm_rf(pasta) }

  def arquivo(nome, *cor)
    File.join(pasta, nome).tap { |caminho| system("convert", "-size", "20x20", *cor, caminho, exception: true) }
  end

  it "averages an RGB file into its sRGB hex and Lab" do
    medida = described_class.new.medir(arquivo("rgb.tif", "xc:#0071BB"))
    expect(medida[:hex]).to eq("#0071BB")
    expect(medida[:lab]).to eq(described_class.lab_do_hex("#0071BB"))
    expect(medida[:lab].map(&:round)).to eq([ 46, 1, -46 ])
  end

  it "takes a CMYK file through the SWOP profile, like the previews" do
    medida = described_class.new.medir(arquivo("cmyk.tif", "-colorspace", "CMYK", "xc:cmyk(0%,75%,85%,0%)"))
    expect(FamiliasDeCor.classificar(medida[:lab])).to eq("Laranja")
  end

  it "averages a file of two colors" do
    medida = described_class.new.medir(arquivo("metade.tif", "xc:#000000", "-size", "20x20", "xc:#FFFFFF", "+append"))
    expect(FamiliasDeCor.classificar(medida[:lab])).to eq("Cinza")
  end

  it "fails naming the file it couldn't read" do
    expect { described_class.new.medir(File.join(pasta, "nao-existe.tif")) }.to raise_error(MedidaDeCor::Falhou, /nao-existe.tif/)
  end
end
