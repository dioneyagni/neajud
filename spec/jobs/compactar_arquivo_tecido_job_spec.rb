require "rails_helper"
require_relative "../support/producao_tecido"
require_relative "../support/fake_compactacao_de_arquivo"

# Etapa 2.7c (decided 19/10/2026): a corrida's or cor lisa's file compacted
# in the background as soon as it is uploaded, so a pedido finds it ready.
RSpec.describe CompactarArquivoTecidoJob do
  let(:client) { create(:client) }
  let(:arquivo) { criar_obra_de_tecido("corrida", client: client).arquivos.first }
  let(:versao) { create(:arquivo_version, arquivo: arquivo, approved: true, status: "processing") }
  let(:copia) { ArquivoCompactadoTecido.new(versao) }

  before do
    arquivo.update!(approved_version: versao)
    gravar_original(arquivo, Rails.root.join("spec/fixtures/files/01.tif"))
  end

  after do
    described_class.compactador = CompactacaoDeArquivo.new
    ActiveJob::Base.queue_adapter = :inline
  end

  it "compacts the version's file beside it and frees the queue" do
    described_class.compactador = FakeCompactacaoDeArquivo.new
    ActiveJob::Base.queue_adapter = :test
    copia.preparar!
    expect(copia.em_fila?).to be(true)
    described_class.perform_now(versao.id)
    expect([ copia.pronto?, copia.em_fila?, copia.falhou? ]).to eq([ true, false, false ])
  end

  it "marks a failure, frees the queue and doesn't compact again when ready" do
    described_class.compactador = FakeCompactacaoDeArquivo.new(falha: true)
    described_class.perform_now(versao.id)
    expect([ copia.pronto?, copia.em_fila?, copia.falhou? ]).to eq([ false, false, true ])
    pronta = ArquivoCompactadoTecido.new(create(:arquivo_version, arquivo: arquivo, status: "processed"))
    described_class.compactador = fake = FakeCompactacaoDeArquivo.new
    FileUtils.mkdir_p(File.dirname(pronta.caminho))
    FileUtils.touch(pronta.caminho)
    described_class.perform_now(pronta.instance_variable_get(:@version).id)
    expect(fake.compactados).to be_empty
  end

  it "is queued when a corrida's version finishes processing, never a calçado's or a DTF's" do
    ActiveJob::Base.queue_adapter = :test
    versao.update!(status: "processed")
    expect(described_class).to have_been_enqueued.with(versao.id)
    calcado = create(:arquivo_version, arquivo: create(:arquivo, client: client), status: "processing")
    calcado.update!(status: "processed")
    expect(described_class).not_to have_been_enqueued.with(calcado.id)
  end

  it "is queued for an arte's files when it becomes a cor lisa" do
    ActiveJob::Base.queue_adapter = :test
    outro = create(:arquivo, category: "artes", client: client)
    pronta = create(:arquivo_version, arquivo: outro, approved: true, status: "processed")
    outro.update!(approved_version: pronta)
    outro.arte.trocar_tipo!("cor_lisa")
    expect(described_class).to have_been_enqueued.with(pronta.id)
  end
end
