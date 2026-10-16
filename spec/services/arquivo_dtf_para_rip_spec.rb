require "rails_helper"
require_relative "../support/producao_dtf"
require_relative "../support/fake_giro_de_arquivo"

# Etapa 2.6b2 (D4, decided 15/10/2026): each line's file for the RIP, named
# with the units to print, turned when the fit turned it.
RSpec.describe ArquivoDtfParaRip do
  let(:pedido) { pedido_dtf_confirmado }
  let(:linhas) { LinhasDeProducao.call(pedido, EtapasProducao.etapa("dtf", "impressao")) }
  let(:titulo) { pedido.itens_pedido.first.arte.arquivos.first.nome_completo(para_arquivo: true).delete_suffix("_P") }

  before do
    gravar_original(arquivo_do_tamanho(pedido, "P"), Rails.root.join("spec/fixtures/files/01.tif"))
    gravar_original(arquivo_do_tamanho(pedido, "G"), Rails.root.join("spec/fixtures/files/02.tif"))
  end

  after { GirarArquivoDtfJob.girador = GiroDeArquivo.new }

  it "sends a standing size's original, the units in the name" do
    rip = described_class.new(linhas.first)
    expect([ rip.estado, rip.nome, rip.caminho ]).to eq([ :pronto, "#{titulo}_P_44un.tif", arquivo_do_tamanho(pedido, "P").approved_version.original_path ])
  end

  it "sends a turned size's copy once ready, preparing it until then" do
    rip = described_class.new(linhas.last)
    expect([ rip.estado, rip.caminho, rip.nome ]).to eq([ :preparando, nil, "#{titulo}_G_18un_girada.tif" ])
    GirarArquivoDtfJob.girador = fake = FakeGiroDeArquivo.new
    rip.preparar! # inline in specs
    expect(fake.girados).to eq([ arquivo_do_tamanho(pedido, "G").approved_version.original_path ])
    expect([ rip.estado, rip.caminho ]).to eq([ :pronto, ArquivoGiradoDtf.new(arquivo_do_tamanho(pedido, "G").approved_version).caminho ])
  end

  it "sends a format the system doesn't turn as it is, for the RIP to turn" do
    arquivo_do_tamanho(pedido, "G").approved_version.update_columns(original_file: "G.psd")
    rip = described_class.new(linhas.last)
    expect([ rip.estado, rip.nome ]).to eq([ :pronto, "#{titulo}_G_18un_girar-no-RIP.psd" ])
    GirarArquivoDtfJob.girador = fake = FakeGiroDeArquivo.new
    rip.preparar!
    expect(fake.girados).to be_empty
  end
end
