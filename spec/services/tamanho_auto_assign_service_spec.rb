require "rails_helper"
require_relative "../support/fake_mold_matcher"

RSpec.describe TamanhoAutoAssignService do
  let(:modelo) { create(:modelo) }
  let(:molde) { create(:molde, modelo: modelo) }
  # Same client as the molde: the fallback never crosses clients (Etapa 1.1, 3/5).
  let(:corte) { create(:arquivo, :corte, organized: true, modelo: modelo, client: molde.client) }
  let!(:first_tamanho) { create(:tamanho, arquivo: corte, nome: "P", position: 1) }
  let(:arte) { create(:arquivo, molde: molde, modelo: modelo) }

  def assign(arte, match: nil)
    described_class.call(arte, matcher: FakeMoldMatcher.new(match))
  end

  it "keeps an already-assigned tamanho without consulting the matcher" do
    other = create(:tamanho, arquivo: corte, nome: "G", position: 2)
    arte.update!(tamanho: other)
    matcher = FakeMoldMatcher.new(first_tamanho)
    expect(matcher).not_to receive(:call)
    described_class.call(arte, matcher: matcher)
    expect(arte.reload.tamanho).to eq(other)
  end

  it "assigns the matcher's tamanho when there is a match" do
    match = create(:tamanho, arquivo: corte, nome: "M", position: 2)
    assign(arte, match: match)
    expect(arte.reload.tamanho).to eq(match)
  end

  it "syncs modelo_id to the matched corte's modelo when they differ" do
    other_modelo = create(:modelo)
    other_corte = create(:arquivo, :corte, organized: true, modelo: other_modelo)
    match = create(:tamanho, arquivo: other_corte)
    assign(arte, match: match)
    expect(arte.reload.modelo_id).to eq(other_modelo.id)
  end

  it "falls back to the first tamanho of the corte linked via the molde's modelo" do
    create(:tamanho, arquivo: corte, nome: "G", position: 2)
    assign(arte, match: nil)
    expect(arte.reload.tamanho).to eq(first_tamanho)
  end

  it "leaves tamanho empty when there is no match and no linked corte" do
    lonely = create(:arquivo, molde: create(:molde))
    assign(lonely, match: nil)
    expect(lonely.reload.tamanho_id).to be_nil
  end
end
