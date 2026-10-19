require "rails_helper"
require_relative "../support/producao_tecido"
require_relative "../support/fake_compactacao_de_arquivo"

# Etapa 2.7c (decided 19/10/2026): each tecido item's file for the RIP —
# the copy compacted at upload, else the original — named with the meters
# and the width to print.
RSpec.describe ArquivoTecidoParaRip do
  let(:pedido) { pedido_tecido_confirmado }
  let(:linhas) { LinhasDeProducao.call(pedido, EtapasProducao.etapa("tecido", "impressao")) }
  let(:corrida) { pedido.itens_pedido.order(:id).first }

  before { gravar_original(corrida.arquivo, Rails.root.join("spec/fixtures/files/01.tif")) }
  after { CompactarArquivoTecidoJob.compactador = CompactacaoDeArquivo.new }

  it "names the file with the item's meters and width, the material's when none was typed" do
    cor = pedido.itens_pedido.order(:id).last.tap { |item| item.arte.update_columns(familia: "Laranja", numero: 1) }
    expect(titulo_do_item(cor.reload)).to start_with("Laranja 1")
    expect(linhas.map { |l| described_class.new(l).nome }).to eq([ "#{titulo_do_item(corrida)}_12,5m_1400mm.tif", "#{titulo_do_item(cor)}_3m_1500mm.tif" ])
  end

  # A cor lisa not measured yet has no name: its file's name stands in.
  it "names an unnamed work by its file" do
    expect(described_class.new(linhas.last).nome).to eq("original_3m_1500mm.tif")
  end

  it "sends the compacted copy once ready, preparing it until then" do
    rip = described_class.new(linhas.first)
    expect([ rip.estado, rip.caminho ]).to eq([ :preparando, nil ])
    CompactarArquivoTecidoJob.compactador = fake = FakeCompactacaoDeArquivo.new
    rip.preparar! # inline in specs
    expect(fake.compactados).to eq([ corrida.arquivo.approved_version.original_path ])
    expect([ rip.estado, rip.caminho ]).to eq([ :pronto, File.join(corrida.arquivo.approved_version.storage_dir, "tecido", "compactado.tif") ])
  end

  it "sends the original when the tool failed, and never tries again" do
    CompactarArquivoTecidoJob.compactador = fake = FakeCompactacaoDeArquivo.new(falha: true)
    rip = described_class.new(linhas.first)
    2.times { rip.preparar! }
    expect(fake.compactados.size).to eq(1)
    expect([ rip.estado, rip.caminho ]).to eq([ :pronto, corrida.arquivo.approved_version.original_path ])
  end

  it "sends a format it doesn't compact as it is" do
    corrida.arquivo.approved_version.update_columns(original_file: "CR.psd")
    rip = described_class.new(linhas.first)
    CompactarArquivoTecidoJob.compactador = fake = FakeCompactacaoDeArquivo.new
    rip.preparar!
    expect([ fake.compactados, rip.estado, rip.nome ]).to eq([ [], :pronto, "#{titulo_do_item(corrida)}_12,5m_1400mm.psd" ])
  end
end
