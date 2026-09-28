require "rails_helper"

RSpec.describe AprovacaoArte do
  let(:user) { create(:user) }
  let(:arte) { create(:arquivo, category: "artes") }
  let(:v1) { create(:arquivo_version, arquivo: arte, version_number: 1, status: :processed) }

  def aprovar(versao = v1, **atributos)
    AprovacaoArte.create!({ arquivo: arte, arquivo_version: versao, user: user, canal: "whatsapp", aprovado_em: Date.current }.merge(atributos))
  end

  it "needs a known channel, and the detail when it is Outro" do
    expect(build(:user) && AprovacaoArte.new(arquivo: arte, arquivo_version: v1, user: user, canal: "pombo", aprovado_em: Date.current)).not_to be_valid
    outro = AprovacaoArte.new(arquivo: arte, arquivo_version: v1, user: user, canal: "outro", aprovado_em: Date.current)
    expect(outro).not_to be_valid
    expect(outro.errors[:canal_detalhe]).to include("is required when the channel is Outro")
  end

  it "refuses a version of another arquivo and cortes" do
    outra = create(:arquivo_version, arquivo: create(:arquivo), version_number: 1)
    expect(AprovacaoArte.new(arquivo: arte, arquivo_version: outra, user: user, canal: "email", aprovado_em: Date.current)).not_to be_valid
    corte = create(:arquivo, :corte)
    versao_corte = create(:arquivo_version, arquivo: corte, version_number: 1)
    aprovacao = AprovacaoArte.new(arquivo: corte, arquivo_version: versao_corte, user: user, canal: "email", aprovado_em: Date.current)
    expect(aprovacao).not_to be_valid
    expect(aprovacao.errors[:arquivo].first).to include("is a corte")
  end

  it "labels the channel" do
    expect(aprovar.rotulo_canal).to eq("WhatsApp")
    expect(aprovar(canal: "outro", canal_detalhe: "Instagram").rotulo_canal).to eq("Outro: Instagram")
  end

  # The path never comes from the stored name: a tampered column can't leave
  # the arte's folder (see the Brakeman note in config/brakeman.ignore).
  it "builds the attachment path from uuids and a fixed extension only" do
    aprovacao = aprovar(anexo_arquivo: "../../../config/master.key", anexo_tipo: "application/pdf")
    expect(aprovacao.anexo_path).to eq(File.join(ArquivoVersion::STORAGE_BASE, arte.uuid, "aprovacoes", "#{aprovacao.uuid}.pdf"))
    expect(aprovar(anexo_arquivo: "x.exe", anexo_tipo: "application/x-msdownload").anexo_path).to be_nil
  end

  it "cancels without deleting" do
    aprovacao = aprovar
    aprovacao.cancelar!(por: user)
    expect(aprovacao.reload).to have_attributes(cancelada?: true, cancelada_por: user)
    expect(AprovacaoArte.validas).to be_empty
  end

  describe "the arte's state (Aprovavel)" do
    before { arte.update!(approved_version: v1) }

    it "waits until the version in use is approved" do
      expect(arte.estado_aprovacao).to eq(:aguardando)
      aprovacao = aprovar
      expect(arte.reload.estado_aprovacao).to eq(:aprovada)
      expect(arte.aprovacao_vigente).to eq(aprovacao)
    end

    # Approvals are per version: the client approved what they saw.
    it "a new version waits again, noting an earlier one was approved" do
      aprovar
      v2 = create(:arquivo_version, arquivo: arte, version_number: 2, status: :processed)
      arte.update!(approved_version: v2)
      expect(arte.reload.estado_aprovacao).to eq(:aguardando)
      expect(arte.aprovada_versao_anterior?).to be true
    end

    it "a cancelled approval doesn't count" do
      aprovar.cancelar!(por: user)
      expect(arte.reload.estado_aprovacao).to eq(:aguardando)
      expect(arte.aprovada_versao_anterior?).to be false
    end
  end
end
