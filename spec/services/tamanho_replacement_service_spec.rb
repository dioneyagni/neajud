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

  it "unlinks artes that pointed at the old tamanhos" do
    old = create(:tamanho, arquivo: corte, position: 1)
    arte = create(:arquivo, tamanho: old)
    described_class.call(corte, submitted("0" => { nome: "P" }))
    expect(arte.reload.tamanho_id).to be_nil
  end

  it "ignores fields the form is not allowed to set" do
    described_class.call(corte, submitted("0" => { nome: "P", preview_file: "/etc/passwd", arquivo_id: 999 }))
    tamanho = corte.tamanhos.reload.first
    expect([ tamanho.preview_file, tamanho.arquivo_id ]).to eq([ nil, corte.id ])
  end
end
