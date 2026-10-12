require "rails_helper"

# Etapa 2.8 (4a): the client asks for changes, with a note.
RSpec.describe PedirAlteracaoService do
  let(:user) { create(:user) }
  let(:arte) do
    create(:arquivo).tap { |a| a.update!(approved_version: create(:arquivo_version, arquivo: a, version_number: 1, status: :processed)) }
  end

  it "records the note and holds the arte at alteração pedida" do
    SolicitacaoAprovacao.create!(arquivo: arte, arquivo_version: arte.approved_version, user: user)
    alteracao = described_class.call(arte, user: user, recado: "  Azul mais escuro ")
    expect(alteracao).to be_persisted.and have_attributes(recado: "Azul mais escuro", user: user)
    expect(arte.estado_aprovacao).to eq(:alteracao_pedida)
  end

  it "refuses a blank note" do
    SolicitacaoAprovacao.create!(arquivo: arte, arquivo_version: arte.approved_version, user: user)
    expect(described_class.call(arte, user: user, recado: " ").errors[:recado]).to be_present
  end

  it "refuses an arte not waiting for approval" do
    expect(described_class.call(arte, user: user, recado: "x")).not_to be_persisted
  end
end
