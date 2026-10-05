require "rails_helper"

# Etapa 1.2 (2/3, parte 2b; decided 05/10/2026): each part of an arte has one
# piloto — the editable master — and its grade of production files.
RSpec.describe PapelNaArte do
  include ActiveSupport::Testing::TimeHelpers
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde) }
  let(:piloto) { com_versao(create(:arquivo, filename: "20-BLUEY AZUL", peca: lateral, molde: molde)) }
  let(:producao) { com_versao(create(:arquivo, arte: piloto.arte, filename: "20-cachorro-LATERAL-29_30", peca: lateral, molde: molde)) }

  def com_versao(arquivo, numero = 1)
    arquivo.tap { |a| a.update!(approved_version: create(:arquivo_version, arquivo: a, version_number: numero, status: :processed)) }
  end

  it "is production by default" do
    expect(create(:arquivo).papel).to eq("producao")
  end

  describe "#tornar_piloto!" do
    it "makes the file its part's piloto, sending the previous one back to production" do
      producao.tornar_piloto!
      expect(piloto.tornar_piloto!).to eq(producao)
      expect([ piloto.reload.papel, producao.reload.papel ]).to eq(%w[piloto producao])
    end

    it "keeps one piloto per part, not per arte" do
      piloto.tornar_piloto!
      da_lingua = create(:arquivo, arte: piloto.arte, peca: lingua)
      expect { da_lingua.tornar_piloto! }.not_to raise_error
      expect(piloto.arte.arquivos.where(papel: "piloto").count).to eq(2)
    end
  end

  it "refuses a second piloto in the same part, naming the one there is" do
    piloto.tornar_piloto!
    producao.papel = "piloto"
    expect(producao).not_to be_valid
    expect(producao.errors[:papel].first).to include('"20-BLUEY AZUL" is already the piloto of Lateral')
  end

  it "is not the same arte uploaded again as the production file of its size" do
    corte = create(:arquivo, :corte, peca: lateral)
    trinta = create(:tamanho, arquivo: corte, nome: "29-30")
    piloto.update!(tamanho: trinta, nome: "Bluey")
    producao.update!(tamanho: trinta, nome: "Bluey")
    expect(producao.artes_com_mesmo_nome).to eq([ piloto ])
    piloto.tornar_piloto!
    expect([ producao.artes_com_mesmo_nome.to_a, piloto.artes_com_mesmo_nome.to_a ]).to eq([ [], [] ])
  end

  describe "#anterior_ao_piloto? (changing the piloto must change the production)" do
    before { piloto.tornar_piloto! }

    it "marks production made before the piloto's new version, until it gets its own" do
      expect(producao.anterior_ao_piloto?).to be false
      travel 1.minute
      com_versao(piloto, 2)
      expect(producao.reload.anterior_ao_piloto?).to be true
      travel 1.minute
      com_versao(producao, 2)
      expect(producao.reload.anterior_ao_piloto?).to be false
    end

    it "doesn't mark the other part's production" do
      outra = com_versao(create(:arquivo, arte: piloto.arte, peca: lingua))
      travel 1.minute
      com_versao(piloto, 2)
      expect(outra.anterior_ao_piloto?).to be false
    end
  end

  it "a new version of the piloto undoes the arte's approval" do
    piloto.tornar_piloto!
    producao
    user = create(:user)
    SolicitacaoAprovacao.create!(arquivo: producao, arquivo_version: producao.approved_version, user: user)
    AprovacaoArte.create!(arquivo: producao, arquivo_version: producao.approved_version, user: user, canal: "whatsapp", aprovado_em: Date.current)
    com_versao(piloto, 2)
    expect(piloto.arte.estado_aprovacao).to eq(:nao_enviada)
  end

  it "comes first in its part on the arte's list" do
    producao.tornar_piloto!
    expect(piloto.arte.arquivos_por_parte[lateral]).to eq([ producao, piloto ])
  end
end
