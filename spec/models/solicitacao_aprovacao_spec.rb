require "rails_helper"

RSpec.describe SolicitacaoAprovacao do
  let(:user) { create(:user) }
  let(:arte) { create(:arquivo, category: "artes") }
  let(:v1) { create(:arquivo_version, arquivo: arte, version_number: 1) }

  it "refuses a version of another arquivo, cortes and trashed artes" do
    outra = create(:arquivo_version, arquivo: create(:arquivo), version_number: 1)
    expect(described_class.new(arquivo: arte, arquivo_version: outra, user: user)).not_to be_valid
    corte = create(:arquivo, :corte)
    pedido_corte = described_class.new(arquivo: corte, arquivo_version: create(:arquivo_version, arquivo: corte, version_number: 1), user: user)
    expect(pedido_corte.tap(&:validate).errors[:arquivo].first).to include("only artes go through approval")
    arte.excluir!(changed_by: "10.0.0.1")
    expect(described_class.new(arquivo: arte, arquivo_version: v1, user: user)).not_to be_valid
  end

  it "cancels without deleting (Cancelavel)" do
    solicitacao = described_class.create!(arquivo: arte, arquivo_version: v1, user: user)
    solicitacao.cancelar!(por: user)
    expect(solicitacao.reload).to have_attributes(cancelada?: true, cancelada_por: user)
    expect(described_class.validas).to be_empty
  end
end
