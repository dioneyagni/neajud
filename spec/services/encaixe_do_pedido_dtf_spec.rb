require "rails_helper"
require_relative "../support/etiquetas_dtf"

# Etapa 2.6b1 (decided 13/10/2026): each etiqueta × size in its own rows
# (D2), the orientation with fewer meters, the last row completed and the
# extra rows — the line's own, else the pedido's (D3).
RSpec.describe EncaixeDoPedidoDtf do
  let(:client) { create(:client) }
  # P: 16,17 × 17,02 mm — 32 a row standing (18,52 mm), 30 turned (17,67 mm).
  let(:etiqueta) { criar_etiqueta_dtf(client: client, tamanhos: { "P" => [ 191, 201 ], "G" => [ 8000, 8000 ] }) }
  let(:pedido) { create(:pedido, client: client, tipo: "dtf") }

  def item_com(grade)
    create(:item_pedido, pedido: pedido, arquivo: etiqueta.arquivos.first).tap do |item|
      grade.each { |tamanho, quantidade| item.grades.create!(tamanho_nome: tamanho, quantidade: quantidade) }
    end
  end

  def linha(tamanho = "P")
    described_class.call(pedido.reload).find { |l| l.grade.tamanho_nome == tamanho }
  end

  it "completes the last row on the orientation with fewer meters; the excess goes to the client" do
    item_com("P" => 100)
    # Standing: 4 rows, 128, 74 mm; turned: 4 rows, 120, 71 mm.
    expect(linha.to_h.slice(:girada, :por_fileira, :fileiras, :impressas, :metros)).to eq(girada: true, por_fileira: 30, fileiras: 4, impressas: 120, metros: 0.0707)
    expect(linha.excedente).to eq(20)
  end

  it "stands on a full row it fills, and takes its own extra rows over the pedido's" do
    item = item_com("P" => 32)
    expect(linha.to_h.slice(:girada, :fileiras, :impressas)).to eq(girada: false, fileiras: 1, impressas: 32)
    pedido.update!(fileiras_extras: 1)
    expect(linha.to_h.slice(:extras, :fileiras, :impressas)).to eq(extras: 1, fileiras: 2, impressas: 64)
    item.grades.find_by!(tamanho_nome: "P").update!(fileiras_extras: 0)
    expect(linha.to_h.slice(:extras, :impressas)).to eq(extras: 0, impressas: 32)
  end

  it "names what can't be fitted: no file of the size, no measure, wider than the film" do
    item_com("G" => 5, "M" => 3)
    etiqueta.arquivos.find_by!(tamanho_rotulo: "P").update_column(:encaixe_dtf, nil)
    item_com("P" => 1)
    expect([ linha("G").pendencia, linha("M").pendencia, linha("P").pendencia ]).to eq(%i[nao_cabe sem_arquivo sem_medida])
  end

  it "keeps a confirmed pedido's fit as written, whatever the etiqueta does next" do
    item_com("P" => 100)
    described_class.gravar!(pedido)
    pedido.update!(status: "confirmado")
    etiqueta.update!(espacamento_mm: 5)
    expect(linha.to_h.slice(:impressas, :metros)).to eq(impressas: 120, metros: 0.0707)
  end
end
