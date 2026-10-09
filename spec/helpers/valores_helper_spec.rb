require "rails_helper"

# Etapa 2.4 (asked 09/10/2026): the "*" of a cost says what is missing.
RSpec.describe ValoresHelper, type: :helper do
  it "groups what is missing by part and reason, with the numbers it touches" do
    reforco = build(:peca, nome: "Reforço")
    falta = CustoPorPar::Falta.new(peca: reforco, motivo: :sem_corte)
    custos = %w[29 30].map { |n| CustoPorPar::Custo.new(numero: n, impressao: 0, corte: 0, faltas: [ falta ]) }
    custos << CustoPorPar::Custo.new(numero: "31", impressao: 0, corte: 0, faltas: [ CustoPorPar::Falta.new(peca: nil, motivo: :sem_medida) ])
    expect(helper.faltas_do_custo(custos + [ nil ])).to eq([
      "Reforço (29, 30): no organized corte serves it — the arte's file can't be tied to the number",
      "Sem peça (31): the file has no size on the paper yet (DPI, or still processing)"
    ])
  end
end
