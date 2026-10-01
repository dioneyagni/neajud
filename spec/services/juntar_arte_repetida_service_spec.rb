require "rails_helper"

RSpec.describe JuntarArteRepetidaService do
  let(:molde) { create(:molde) }
  let(:tamanho) { create(:tamanho) }
  let(:referencia) { create(:referencia, molde: molde) }

  # An arte with its version in use and the original file on disk.
  def arte_com_arquivo(filename)
    arte = create(:arquivo, category: "artes", molde: molde, referencia: referencia, nome: "Bluey", tamanho: tamanho, filename: filename)
    versao = create(:arquivo_version, arquivo: arte, version_number: 1, approved: true, extension: "tif", original_file: "#{filename}.tif")
    FileUtils.mkdir_p(File.dirname(versao.original_path))
    File.write(versao.original_path, "conteudo de #{filename}")
    arte.update!(approved_version: versao)
    arte
  end

  let!(:original) { arte_com_arquivo("primeira") }
  let!(:repetida) { arte_com_arquivo("segunda") }

  def juntar = described_class.call(repetida: repetida, original: original, changed_by: "10.0.0.1")

  it "copies the newer file as the original's new version in use, and trashes the newer record" do
    anterior = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    expect { juntar }.to have_enqueued_job(ArquivoProcessingJob)
    nova = original.reload.approved_version
    expect([ nova.version_number, File.read(nova.original_path), nova.original_file ]).to eq([ 2, "conteudo de segunda", "segunda.tif" ])
    expect(repetida.reload).to be_excluido
    expect(File.exist?(repetida.approved_version.original_path)).to be true
  ensure
    ActiveJob::Base.queue_adapter = anterior
  end

  it "refuses two artes that don't share the full name" do
    repetida.update_columns(nome: "Outro")
    expect { juntar }.to raise_error(described_class::Recusado, /are not the same full name/)
    expect(original.reload.arquivo_versions.count).to eq(1)
  end

  # Its pedidos would lose their arte: replace it there first.
  it "refuses an arte that is already in a pedido" do
    create(:item_pedido, arquivo: repetida)
    expect { juntar }.to raise_error(described_class::Recusado, /"segunda" is already in a pedido/)
    expect(repetida.reload).not_to be_excluido
  end
end
