require "rails_helper"

RSpec.describe BaixaProducao do
  let(:pedido) { create(:pedido, status: "confirmado") }

  it "needs a level it knows, a measure and at least one line" do
    baixa = pedido.baixas_producao.build(etapa: "corte", nivel: "lote", medida: -1, linhas: [])
    expect(baixa).not_to be_valid
    expect(baixa.errors.full_messages).to contain_exactly(
      "Nivel lote is not a level; expected linha, referencia, pedido", "Medida must be greater than or equal to 0",
      "Linhas can't be empty: a baixa covers at least one production line"
    )
  end

  it "lists the lines done by the baixas still standing, per stage" do
    pedido.baixas_producao.create!(etapa: "corte", nivel: "linha", medida: 1, linhas: %w[a])
    pedido.baixas_producao.create!(etapa: "corte", nivel: "pedido", medida: 1, linhas: %w[b c])
    pedido.baixas_producao.create!(etapa: "corte", nivel: "linha", medida: 1, linhas: %w[d], desfeita_em: Time.current)
    pedido.baixas_producao.create!(etapa: "impressao", nivel: "linha", medida: 1, linhas: %w[e])
    expect(pedido.baixas_producao.vigentes.da_etapa("corte").feitas).to eq(Set.new(%w[a b c]))
  end
end
