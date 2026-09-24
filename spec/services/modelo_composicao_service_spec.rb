require "rails_helper"

RSpec.describe ModeloComposicaoService do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde).tap { |m| m.pecas << [ lateral, lingua ] } }
  let(:modelo) { create(:modelo, molde: molde).tap(&:sync_modelo_pecas!) }

  # An arte gets its peça through tamanho → corte, like in production data.
  def arte_for(peca, modelo: self.modelo)
    corte = create(:arquivo, :corte, peca: peca)
    create(:arquivo, modelo: modelo, tamanho: create(:tamanho, arquivo: corte))
  end

  def pieces(slots)
    slots.map { |slot| [ slot.peca&.nome, slot.arquivo ] }
  end

  it "returns one slot per peça of the modelo, each with its arte" do
    arte_lateral = arte_for(lateral)
    arte_lingua = arte_for(lingua)
    expect(pieces(described_class.call(arte_lateral))).to eq([ [ "Lateral", arte_lateral ], [ "Língua", arte_lingua ] ])
  end

  it "leaves the arte empty (pending) for a peça that has none" do
    arte_lateral = arte_for(lateral)
    expect(pieces(described_class.call(arte_lateral))).to eq([ [ "Lateral", arte_lateral ], [ "Língua", nil ] ])
  end

  it "uses the arte's own peca_id when it has no tamanho yet" do
    arte_lateral = arte_for(lateral)
    linked = create(:arquivo, modelo: modelo, peca: lingua)
    expect(described_class.call(arte_lateral).map(&:arquivo)).to eq([ arte_lateral, linked ])
  end

  it "falls back to the molde's pieces when modelo_pecas were never synced, without writing them" do
    unsynced = create(:modelo, molde: molde)
    arte_lateral = arte_for(lateral, modelo: unsynced)
    expect(pieces(described_class.call(arte_lateral)).map(&:first)).to eq([ "Lateral", "Língua" ])
    expect(unsynced.modelo_pecas.reload).to be_empty
  end

  it "adds the arte itself when its peça is unknown" do
    arte_lateral = arte_for(lateral)
    unknown = create(:arquivo, modelo: modelo)
    expect(pieces(described_class.call(unknown))).to eq([ [ "Lateral", arte_lateral ], [ "Língua", nil ], [ nil, unknown ] ])
  end

  it "leaves out other artes of the modelo whose peça is unknown (they are candidates, not pieces)" do
    arte_lateral = arte_for(lateral)
    create(:arquivo, modelo: modelo)
    expect(described_class.call(arte_lateral).map(&:arquivo)).to eq([ arte_lateral, nil ])
  end

  it "keeps an arte whose peça is not on the modelo (e.g. the molde changed)" do
    arte_lateral = arte_for(lateral)
    palmilha = arte_for(create(:peca, nome: "Palmilha"))
    expect(pieces(described_class.call(arte_lateral)).last).to eq([ "Palmilha", palmilha ])
  end

  it "ignores artes of other modelos" do
    arte_lateral = arte_for(lateral)
    arte_for(lingua, modelo: create(:modelo, molde: molde))
    expect(described_class.call(arte_lateral).map(&:arquivo)).to eq([ arte_lateral, nil ])
  end

  it "is a single slot for an arte without modelo" do
    lone = create(:arquivo, peca: lateral)
    expect(pieces(described_class.call(lone))).to eq([ [ "Lateral", lone ] ])
  end
end
