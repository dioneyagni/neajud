require "rails_helper"

# Painel 3/4a (Q1a, Q4): each stage's last move gives its order; a pedido's
# history is its own moves and the ones that pushed it.
RSpec.describe MovimentoDaFila do
  let(:pessoa) { create(:user) }
  let(:movido) { create(:pedido) }
  let(:empurrado) { create(:pedido) }
  let(:outro) { create(:pedido) }

  def mover(pedido, ordem_em, etapa: "impressao", empurrados: [])
    described_class.create!(pedido: pedido, user: pessoa, etapa: etapa, setor: etapa, de: 2, para: 1, ordem_em: ordem_em, empurrados: empurrados)
  end

  it "gives each moved stage the order of its last move, none once back to the arrival" do
    mover(movido, 2.hours.ago)
    ultimo = mover(movido, 3.hours.ago)
    corte = mover(movido, 1.hour.ago, etapa: "corte")
    mover(outro, 1.hour.ago)
    mover(outro, nil)

    expect(described_class.ordens).to eq([ movido.id, "impressao" ] => ultimo, [ movido.id, "corte" ] => corte)
  end

  it "reads each pedido's moves at once: its own and the ones that pushed it" do
    proprio = mover(movido, 1.hour.ago, empurrados: [ { "pedido_id" => empurrado.id, "de" => "2026-11-04T10:00:00-03:00", "para" => nil } ])
    mover(outro, 1.hour.ago)

    expect(described_class.por_pedido([ movido.id, empurrado.id ])).to eq(movido.id => [ proprio ], empurrado.id => [ proprio ])
    expect(described_class.do_pedido(empurrado)).to eq([ proprio ])
    expect([ proprio.empurrado(empurrado), proprio.empurrado(outro) ]).to eq([ { "pedido_id" => empurrado.id, "de" => "2026-11-04T10:00:00-03:00", "para" => nil }, nil ])
    expect(described_class.none.por_pedido([ movido.id ])).to eq(movido.id => [])
  end
end
