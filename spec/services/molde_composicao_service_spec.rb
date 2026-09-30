require "rails_helper"

RSpec.describe MoldeComposicaoService do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:modelo) { create(:modelo).tap { |m| m.pecas << [ lateral, lingua ] } }
  let(:molde) { create(:molde, modelo: modelo).tap(&:sync_molde_pecas!) }

  # An arte gets its peça through tamanho → corte, like in production data.
  def arte_for(peca, molde: self.molde)
    corte = create(:arquivo, :corte, peca: peca)
    create(:arquivo, molde: molde, tamanho: create(:tamanho, arquivo: corte))
  end

  def pieces(slots)
    slots.map { |slot| [ slot.peca&.nome, slot.arquivo ] }
  end

  it "returns one slot per peça of the molde, each with its arte" do
    arte_lateral = arte_for(lateral)
    arte_lingua = arte_for(lingua)
    expect(pieces(described_class.call(arte_lateral))).to eq([ [ "Lateral", arte_lateral ], [ "Língua", arte_lingua ] ])
  end

  # Etapa 0.4: trashed artes and peças never become new pedido pieces.
  it "skips trashed artes (pending slot) and trashed peças (no slot)" do
    arte_lateral = arte_for(lateral)
    arte_for(lingua).excluir!(changed_by: "10.0.0.1")
    expect(pieces(described_class.call(arte_lateral))).to eq([ [ "Lateral", arte_lateral ], [ "Língua", nil ] ])

    lingua.excluir!(changed_by: "10.0.0.1")
    expect(pieces(described_class.call(arte_lateral))).to eq([ [ "Lateral", arte_lateral ] ])
  end

  it "leaves the arte empty (pending) for a peça that has none" do
    arte_lateral = arte_for(lateral)
    expect(pieces(described_class.call(arte_lateral))).to eq([ [ "Lateral", arte_lateral ], [ "Língua", nil ] ])
  end

  it "uses the arte's own peca_id when it has no tamanho yet" do
    arte_lateral = arte_for(lateral)
    linked = create(:arquivo, molde: molde, peca: lingua)
    expect(described_class.call(arte_lateral).map(&:arquivo)).to eq([ arte_lateral, linked ])
  end

  it "falls back to the modelo's pieces when molde_pecas were never synced, without writing them" do
    unsynced = create(:molde, modelo: modelo)
    arte_lateral = arte_for(lateral, molde: unsynced)
    expect(pieces(described_class.call(arte_lateral)).map(&:first)).to eq([ "Lateral", "Língua" ])
    expect(unsynced.molde_pecas.reload).to be_empty
  end

  it "adds the arte itself when its peça is unknown" do
    arte_lateral = arte_for(lateral)
    unknown = create(:arquivo, molde: molde)
    expect(pieces(described_class.call(unknown))).to eq([ [ "Lateral", arte_lateral ], [ "Língua", nil ], [ nil, unknown ] ])
  end

  it "leaves out other artes of the molde whose peça is unknown (they are candidates, not pieces)" do
    arte_lateral = arte_for(lateral)
    create(:arquivo, molde: molde)
    expect(described_class.call(arte_lateral).map(&:arquivo)).to eq([ arte_lateral, nil ])
  end

  it "keeps an arte whose peça is not on the molde (e.g. the modelo changed)" do
    arte_lateral = arte_for(lateral)
    palmilha = arte_for(create(:peca, nome: "Palmilha"))
    expect(pieces(described_class.call(arte_lateral)).last).to eq([ "Palmilha", palmilha ])
  end

  it "ignores artes of other moldes" do
    arte_lateral = arte_for(lateral)
    arte_for(lingua, molde: create(:molde, modelo: modelo))
    expect(described_class.call(arte_lateral).map(&:arquivo)).to eq([ arte_lateral, nil ])
  end

  # Regression: dev data had two línguas on one molde; adding the second one
  # showed the first and dropped the added arte.
  it "puts the added arte in its peça even when another arte of the molde claims it too" do
    arte_lateral = arte_for(lateral)
    arte_for(lingua)
    added = arte_for(lingua)
    first_lingua = molde.arquivos.where.not(id: [ arte_lateral.id, added.id ]).sole
    expect(described_class.call(added).map(&:arquivo)).to eq([ arte_lateral, added ])
    expect(described_class.call(first_lingua).map(&:arquivo)).to eq([ arte_lateral, first_lingua ])
  end

  it "is a single slot for an arte without molde" do
    lone = create(:arquivo, peca: lateral)
    expect(pieces(described_class.call(lone))).to eq([ [ "Lateral", lone ] ])
  end
end
