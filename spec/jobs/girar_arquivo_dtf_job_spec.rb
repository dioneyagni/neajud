require "rails_helper"
require_relative "../support/producao_dtf"
require_relative "../support/fake_giro_de_arquivo"

# Etapa 2.6b2 (D4): the turned copy for the RIP, made in the background.
RSpec.describe GirarArquivoDtfJob do
  let(:pedido) { pedido_dtf_confirmado }
  let(:arquivo) { arquivo_do_tamanho(pedido, "G") }
  let(:girada) { ArquivoGiradoDtf.new(arquivo.approved_version) }

  before { gravar_original(arquivo, Rails.root.join("spec/fixtures/files/01.tif")) }
  after do
    described_class.girador = GiroDeArquivo.new
    ActiveJob::Base.queue_adapter = :inline
  end

  it "turns the version's file beside it and frees the queue" do
    described_class.girador = FakeGiroDeArquivo.new
    ActiveJob::Base.queue_adapter = :test
    girada.preparar!
    expect(girada.em_fila?).to be(true)
    ActiveJob::Base.queue_adapter = :inline
    described_class.perform_now(arquivo.approved_version.id)
    expect([ girada.pronto?, girada.em_fila?, girada.caminho ]).to eq([ true, false, File.join(arquivo.approved_version.storage_dir, "dtf", "girada.tif") ])
  end

  it "doesn't turn it again when it is ready" do
    described_class.girador = fake = FakeGiroDeArquivo.new
    2.times { described_class.perform_now(arquivo.approved_version.id) }
    expect(fake.girados.size).to eq(1)
  end

  # A file the tool can't turn would otherwise be queued on every visit.
  it "marks a failure, never tried again: the original goes, for the RIP to turn" do
    described_class.girador = FakeGiroDeArquivo.new(falha: true)
    expect(Rails.logger).to receive(:error).with(/GirarArquivoDtfJob.*fake failure/)
    described_class.perform_now(arquivo.approved_version.id)
    expect([ girada.pronto?, girada.em_fila?, girada.gira? ]).to eq([ false, false, false ])
    girada.preparar!
    expect(described_class.girador.girados.size).to eq(1)
  end
end
