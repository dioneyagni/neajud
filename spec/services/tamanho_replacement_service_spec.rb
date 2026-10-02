require "rails_helper"

RSpec.describe TamanhoReplacementService do
  let(:corte) { create(:arquivo, :corte) }

  def submitted(rows)
    ActionController::Parameters.new(rows)
  end

  it "replaces the tamanhos with the submitted rows, ordered by numeric key" do
    create(:tamanho, arquivo: corte, nome: "Old", position: 1)
    described_class.call(corte, submitted(
      "10" => { nome: "G", width_mm: "30" }, "2" => { nome: "M", width_mm: "20" }, "0" => { nome: "P", width_mm: "10" }
    ))
    rows = corte.tamanhos.reload.order(:position).map { |t| [ t.nome, t.position, t.width_mm.to_f ] }
    expect(rows).to eq([ [ "P", 1, 10.0 ], [ "M", 2, 20.0 ], [ "G", 3, 30.0 ] ])
  end

  it "names blank rows \"Size <position>\"" do
    described_class.call(corte, submitted("0" => { nome: "" }, "1" => { nome: "M" }))
    expect(corte.tamanhos.reload.order(:position).pluck(:nome)).to eq([ "Size 1", "M" ])
  end

  it "keeps each position's preview image" do
    create(:tamanho, arquivo: corte, position: 1, preview_file: "/previews/1.svg")
    create(:tamanho, arquivo: corte, position: 2, preview_file: "/previews/2.svg")
    described_class.call(corte, submitted("0" => { nome: "A" }, "1" => { nome: "B" }, "2" => { nome: "C" }))
    expect(corte.tamanhos.reload.order(:position).pluck(:preview_file)).to eq([ "/previews/1.svg", "/previews/2.svg", nil ])
  end

  it "updates the tamanhos in place: same uuid, the arte stays linked" do
    old = create(:tamanho, arquivo: corte, position: 1, nome: "24")
    arte = create(:arquivo, tamanho: old)
    described_class.call(corte, submitted("0" => { tamanhos: "24" }), tipo: "par")
    expect([ corte.tamanhos.reload.pluck(:uuid), arte.reload.tamanho_id ]).to eq([ [ old.uuid ], old.id ])
  end

  it "unlinks only the artes of tamanhos past the new list" do
    create(:tamanho, arquivo: corte, position: 1)
    sobra = create(:tamanho, arquivo: corte, position: 2)
    arte = create(:arquivo, tamanho: sobra)
    described_class.call(corte, submitted("0" => { nome: "P" }))
    expect([ corte.tamanhos.reload.count, arte.reload.tamanho_id ]).to eq([ 1, nil ])
  end

  it "saves the label and the individual sizes of the grade type" do
    described_class.call(corte, submitted("0" => { tamanhos: "30" }, "1" => { rotulo: "", tamanhos: "31-32" }), tipo: "par")
    expect(corte.tamanhos.reload.order(:position).map { |t| [ t.nome, t.numeros ] }).to eq([ [ "29-30", %w[29 30] ], [ "31-32", %w[31 32] ] ])
  end

  it "refuses the whole list when a row doesn't fit the type, saving nothing" do
    create(:tamanho, arquivo: corte, position: 1, nome: "24")
    substituicao = described_class.new(corte, submitted("0" => { tamanhos: "30" }, "1" => { tamanhos: "31-32-33" }), tipo: "par")
    expect(substituicao.erro).to start_with('Size 2: "31-32-33" isn\'t a Par pair')
    expect { substituicao.call }.to raise_error(ArgumentError, /Refused tamanhos/)
    expect(corte.tamanhos.reload.pluck(:nome)).to eq([ "24" ])
  end

  it "ignores fields the form is not allowed to set" do
    described_class.call(corte, submitted("0" => { nome: "P", preview_file: "/etc/passwd", arquivo_id: 999 }))
    tamanho = corte.tamanhos.reload.first
    expect([ tamanho.preview_file, tamanho.arquivo_id ]).to eq([ nil, corte.id ])
  end
end
