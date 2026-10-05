require "rails_helper"

RSpec.describe RegistrarAprovacaoService do
  let(:user) { create(:user) }
  let(:arte) do
    create(:arquivo, category: "artes").tap do |a|
      a.update!(approved_version: create(:arquivo_version, arquivo: a, version_number: 1, status: :processed))
      SolicitacaoAprovacao.create!(arquivo: a, arquivo_version: a.approved_version, user: user)
    end
  end
  let(:dados) { { canal: "whatsapp", aprovado_em: "2026-09-20", observacao: "ok pelo zap" } }

  def upload(conteudo, nome)
    arquivo = Tempfile.new([ "anexo", File.extname(nome) ]).tap { |f| f.binmode; f.write(conteudo); f.rewind }
    Rack::Test::UploadedFile.new(arquivo.path, "application/octet-stream", true, original_filename: nome)
  end

  after { FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, arte.uuid)) }

  it "records the version in use, who, when and how" do
    aprovacao = described_class.call(arte, user: user, dados: dados)
    expect(aprovacao).to be_persisted
    expect(aprovacao).to have_attributes(arquivo_version: arte.approved_version, user: user, canal: "whatsapp",
                                         aprovado_em: Date.new(2026, 9, 20), observacao: "ok pelo zap", anexo_arquivo: nil)
  end

  it "stores a PNG/JPEG/PDF attachment named by uuid, keeping the original name" do
    aprovacao = described_class.call(arte, user: user, dados: dados, anexo: upload("%PDF-1.4 fake", "email do cliente.pdf"))
    expect(aprovacao).to have_attributes(anexo_nome: "email do cliente.pdf", anexo_tipo: "application/pdf", anexo_arquivo: "#{aprovacao.uuid}.pdf")
    expect(File.binread(aprovacao.anexo_path)).to eq("%PDF-1.4 fake")
  end

  # The type comes from the content: a renamed text file is not a PDF.
  it "refuses an attachment that isn't PNG, JPEG or PDF by content, saving nothing" do
    aprovacao = described_class.call(arte, user: user, dados: dados, anexo: upload("just text", "falso.pdf"))
    expect(aprovacao).not_to be_persisted
    expect(aprovacao.errors[:anexo].first).to include("falso.pdf is not a PNG, JPEG or PDF")
    expect(AprovacaoArte.count).to eq(0)
  end

  it "refuses an attachment over 20 MB" do
    grande = upload("\x89PNG\r\n\x1A\n".b + ("0" * (20.megabytes + 1)), "print.png")
    aprovacao = described_class.call(arte, user: user, dados: dados, anexo: grande)
    expect(aprovacao.errors[:anexo].first).to include("expected at most 20 MB")
  end

  it "refuses an arte that was not sent for approval" do
    arte.arte.solicitacoes_aprovacao.each { |s| s.cancelar!(por: user) }
    aprovacao = described_class.call(arte.reload, user: user, dados: dados)
    expect(aprovacao.errors[:base]).to include("#{arte.filename} is not sent for approval; send it for approval first")
  end

  it "defaults the date to today" do
    expect(described_class.call(arte, user: user, dados: dados.merge(aprovado_em: "")).aprovado_em).to eq(Date.current)
  end
end
