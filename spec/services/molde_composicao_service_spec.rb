require "rails_helper"

RSpec.describe MoldeComposicaoService do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }

  # A file gets its peça through tamanho → corte, like in production data;
  # arte: the envelope it belongs to (a new one when nil).
  def arquivo_for(peca, molde: self.molde, arte: nil)
    corte = create(:arquivo, :corte, peca: peca)
    create(:arquivo, molde: molde, arte: arte, tamanho: create(:tamanho, arquivo: corte))
  end

  def pieces(slots)
    slots.map { |slot| [ slot.peca&.nome, slot.arquivo ] }
  end

  it "returns one slot per peça of the molde, each with a file of the arte" do
    lateral_file = arquivo_for(lateral)
    lingua_file = arquivo_for(lingua, arte: lateral_file.arte)
    expect(pieces(described_class.call(lateral_file))).to eq([ [ "Lateral", lateral_file ], [ "Língua", lingua_file ] ])
  end

  # Etapa 1.2 (3/3, decided 05/10/2026): the pedido reads the arte; another
  # arte of the same molde doesn't fill its parts.
  it "leaves a part pending when only another arte of the molde has it" do
    lateral_file = arquivo_for(lateral)
    arquivo_for(lingua)
    expect(pieces(described_class.call(lateral_file))).to eq([ [ "Lateral", lateral_file ], [ "Língua", nil ] ])
  end

  # Etapa 0.4: trashed files and peças never become new pedido pieces.
  it "skips trashed files (pending slot) and trashed peças (no slot)" do
    lateral_file = arquivo_for(lateral)
    arquivo_for(lingua, arte: lateral_file.arte).excluir!(changed_by: "10.0.0.1")
    expect(pieces(described_class.call(lateral_file))).to eq([ [ "Lateral", lateral_file ], [ "Língua", nil ] ])

    lingua.excluir!(changed_by: "10.0.0.1")
    expect(pieces(described_class.call(lateral_file))).to eq([ [ "Lateral", lateral_file ] ])
  end

  it "uses a file's own peca_id when it has no tamanho yet" do
    lateral_file = arquivo_for(lateral)
    linked = create(:arquivo, molde: molde, peca: lingua, arte: lateral_file.arte)
    expect(described_class.call(lateral_file).map(&:arquivo)).to eq([ lateral_file, linked ])
  end

  # Etapa 1.1 (3/5): parts belong to the molde; the category has none to
  # fall back to.
  it "gives a molde without parts just the added file" do
    sem_partes = create(:molde, modelo: create(:modelo))
    lateral_file = arquivo_for(lateral, molde: sem_partes)
    expect(pieces(described_class.call(lateral_file))).to eq([ [ "Lateral", lateral_file ] ])
  end

  it "adds the file itself when its peça is unknown" do
    lateral_file = arquivo_for(lateral)
    unknown = create(:arquivo, molde: molde, arte: lateral_file.arte)
    expect(pieces(described_class.call(unknown))).to eq([ [ "Lateral", lateral_file ], [ "Língua", nil ], [ nil, unknown ] ])
  end

  it "leaves out the arte's other files whose peça is unknown" do
    lateral_file = arquivo_for(lateral)
    create(:arquivo, molde: molde, arte: lateral_file.arte)
    expect(described_class.call(lateral_file).map(&:arquivo)).to eq([ lateral_file, nil ])
  end

  it "keeps a file whose peça is not on the molde (e.g. the modelo changed)" do
    lateral_file = arquivo_for(lateral)
    palmilha = arquivo_for(create(:peca, nome: "Palmilha"), arte: lateral_file.arte)
    expect(pieces(described_class.call(lateral_file)).last).to eq([ "Palmilha", palmilha ])
  end

  # Regression: dev data had two línguas on one molde; adding the second one
  # showed the first and dropped the added file.
  it "puts the added file in its peça even when another file of the arte claims it too" do
    lateral_file = arquivo_for(lateral)
    first_lingua = arquivo_for(lingua, arte: lateral_file.arte)
    added = arquivo_for(lingua, arte: lateral_file.arte)
    expect(described_class.call(added).map(&:arquivo)).to eq([ lateral_file, added ])
    expect(described_class.call(first_lingua).map(&:arquivo)).to eq([ lateral_file, first_lingua ])
  end

  it "is a single slot for a file without molde" do
    lone = create(:arquivo, peca: lateral)
    expect(pieces(described_class.call(lone))).to eq([ [ "Lateral", lone ] ])
  end
end
