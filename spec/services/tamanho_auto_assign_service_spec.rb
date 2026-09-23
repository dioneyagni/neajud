require "rails_helper"
require_relative "../support/fake_mold_matcher"

RSpec.describe TamanhoAutoAssignService do
  let(:molde) { create(:molde) }
  let(:corte) { create(:arquivo, :corte, organized: true, molde: molde) }
  let!(:first_tamanho) { create(:tamanho, arquivo: corte, nome: "P", position: 1) }
  let(:arte) { create(:arquivo, modelo: create(:modelo, molde: molde), molde: molde) }

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

  it "syncs molde_id to the matched corte's molde when they differ" do
    other_molde = create(:molde)
    other_corte = create(:arquivo, :corte, organized: true, molde: other_molde)
    match = create(:tamanho, arquivo: other_corte)
    assign(arte, match: match)
    expect(arte.reload.molde_id).to eq(other_molde.id)
  end

  it "falls back to the first tamanho of the corte linked via the modelo's molde" do
    create(:tamanho, arquivo: corte, nome: "G", position: 2)
    assign(arte, match: nil)
    expect(arte.reload.tamanho).to eq(first_tamanho)
  end

  it "leaves tamanho empty when there is no match and no linked corte" do
    lonely = create(:arquivo, modelo: create(:modelo))
    assign(lonely, match: nil)
    expect(lonely.reload.tamanho_id).to be_nil
  end
end
