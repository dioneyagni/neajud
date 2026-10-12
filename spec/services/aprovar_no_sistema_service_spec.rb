require "rails_helper"

# Etapa 2.8 (4a, decided 12/10/2026): the client approves the versions he picks.
RSpec.describe AprovarNoSistemaService do
  let(:user) { create(:user) }
  let(:lateral) { com_versoes(create(:arquivo, filename: "lateral"), 2) }
  let!(:lingua) { com_versoes(create(:arquivo, arte: lateral.arte, filename: "lingua"), 1) }

  def com_versoes(arquivo, quantas)
    versoes = (1..quantas).map { |n| create(:arquivo_version, arquivo: arquivo, version_number: n, status: :processed) }
    arquivo.tap { |a| a.update!(approved_version: versoes.last) }
  end

  def enviar
    SolicitacaoAprovacao.create!(arquivo: lateral, arquivo_version: lateral.approved_version, user: user)
  end

  it "photographs the versions in use when he picks none: the arte is approved" do
    enviar
    aprovacao = described_class.call(lateral, user: user)
    expect(aprovacao).to be_persisted.and have_attributes(canal: "sistema", rotulo_canal: "No sistema", user: user)
    expect(lateral.estado_aprovacao).to eq(:aprovada)
  end

  it "photographs the version he picks: approved in another version" do
    enviar
    v1 = lateral.arquivo_versions.find_by(version_number: 1)
    aprovacao = described_class.call(lateral, user: user, versoes: { lateral.uuid => v1.uuid })
    expect(aprovacao.versoes_por_arquivo).to eq(lateral.id => v1.id, lingua.id => lingua.approved_version_id)
    expect(lateral.estado_aprovacao).to eq(:aprovada_em_outra_versao)
  end

  it "refuses another file's version" do
    enviar
    expect { described_class.call(lateral, user: user, versoes: { lateral.uuid => lingua.approved_version.uuid }) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "refuses an arte not waiting for approval" do
    aprovacao = described_class.call(lateral, user: user)
    expect(aprovacao).not_to be_persisted
    expect(aprovacao.errors.full_messages.to_sentence).to include("not sent for approval")
  end
end
