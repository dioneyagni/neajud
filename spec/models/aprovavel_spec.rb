require "rails_helper"

# Etapa 1.2 (2/3, parte 2): the client approves the arte — one request and one
# approval for all its files, each keeping a photo of their versions in use
# (decided 02/10/2026).
RSpec.describe Aprovavel do
  let(:user) { create(:user) }
  let(:lateral) { com_versao(create(:arquivo, filename: "lateral")) }
  let!(:lingua) { com_versao(create(:arquivo, arte: lateral.arte, filename: "lingua")) }
  let(:arte) { lateral.arte }

  def com_versao(arquivo, numero = 1)
    arquivo.tap { |a| a.update!(approved_version: create(:arquivo_version, arquivo: a, version_number: numero, status: :processed)) }
  end

  def enviar(arquivo = lateral)
    SolicitacaoAprovacao.create!(arquivo: arquivo, arquivo_version: arquivo.approved_version, user: user)
  end

  def aprovar(arquivo = lateral)
    AprovacaoArte.create!(arquivo: arquivo, arquivo_version: arquivo.approved_version, user: user, canal: "whatsapp", aprovado_em: Date.current)
  end

  it "one request and one approval, from any file's page, cover the whole arte" do
    enviar(lingua)
    expect(lateral.estado_aprovacao).to eq(:aguardando)
    aprovacao = aprovar
    expect([ lateral.estado_aprovacao, lingua.estado_aprovacao ]).to eq([ :aprovada, :aprovada ])
    expect(aprovacao.versoes_por_arquivo).to eq(lateral.id => lateral.approved_version_id, lingua.id => lingua.approved_version_id)
  end

  it "a new version of any file starts over, and says which file changed" do
    enviar
    aprovar
    com_versao(lingua, 2)
    expect(arte.estado_aprovacao).to eq(:nao_enviada)
    expect(arte.alterada_depois_da_aprovacao?).to be true
    expect([ arte.alterado_depois_da_aprovacao?(lingua), arte.alterado_depois_da_aprovacao?(lateral) ]).to eq([ true, false ])
  end

  it "a new version also undoes a request still waiting: the client saw the old one" do
    enviar
    com_versao(lateral, 2)
    expect(arte.estado_aprovacao).to eq(:nao_enviada)
  end

  it "a file added after the approval keeps the arte approved, marked as after it" do
    enviar
    aprovar
    novo = com_versao(create(:arquivo, arte: arte))
    expect(arte.estado_aprovacao).to eq(:aprovada)
    expect([ arte.depois_da_aprovacao?(novo), arte.depois_da_aprovacao?(lateral) ]).to eq([ true, false ])
  end

  it "ignores files that left the arte, but not when none of the approved files is left" do
    enviar
    aprovar
    lingua.excluir!(changed_by: "spec")
    expect(arte.estado_aprovacao).to eq(:aprovada)
    com_versao(create(:arquivo, arte: arte))
    lateral.excluir!(changed_by: "spec")
    expect(arte.estado_aprovacao).to eq(:nao_enviada)
  end

  it "only the latest record counts; cancelling it falls back to the one before" do
    enviar
    primeira = aprovar
    segunda = aprovar
    segunda.cancelar!(por: user)
    expect(arte.aprovacao_vigente).to eq(primeira)
  end

  it "joining brings the approval history along" do
    enviar
    aprovar
    outra = com_versao(create(:arquivo))
    JuntarArtesService.call(origem: lateral, destino: outra)
    expect(outra.arte.aprovacoes_arte.count).to eq(1)
    expect([ outra.estado_aprovacao, outra.arte.depois_da_aprovacao?(outra) ]).to eq([ :aprovada, true ])
  end
end
