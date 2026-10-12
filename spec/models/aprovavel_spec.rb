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

  # Etapa 2.8 (4a, decided 12/10/2026): the client answers in the system.
  describe "the client's answers" do
    def pedir_alteracao(recado = "Azul mais escuro")
      AlteracaoArte.create!(arquivo: lateral, arquivo_version: lateral.approved_version, user: user, recado: recado)
    end

    it "asking for changes holds the arte until the team sends it again" do
      enviar
      alteracao = pedir_alteracao
      expect([ arte.estado_aprovacao, arte.alteracao_pedida ]).to eq([ :alteracao_pedida, alteracao ])
      enviar
      expect(arte.estado_aprovacao).to eq(:aguardando)
    end

    it "approving other versions waits for the team, then is approved once they are in use" do
      v1 = lateral.approved_version
      enviar(com_versao(lateral, 2))
      aprovacao = AprovacaoArte.create!(arquivo: lateral, arquivo_version: v1, user: user, canal: "sistema", aprovado_em: Date.current,
                                        arquivo_version_ids: [ v1.id, lingua.approved_version_id ])
      expect([ arte.estado_aprovacao, arte.aprovacao_em_outra_versao ]).to eq([ :aprovada_em_outra_versao, aprovacao ])
      # It never matched, so it isn't "changed after the approval".
      expect([ arte.alterada_depois_da_aprovacao?, arte.alterado_depois_da_aprovacao?(lateral) ]).to eq([ false, false ])

      lateral.update!(approved_version: v1)
      expect(arte.reload.estado_aprovacao).to eq(:aprovada)
    end

    it "an answer before the request in force doesn't count" do
      enviar
      pedir_alteracao
      SolicitacaoAprovacao.create!(arquivo: lateral, arquivo_version: lateral.approved_version, user: user)
      expect(arte.estado_aprovacao).to eq(:aguardando)
    end
  end
end
