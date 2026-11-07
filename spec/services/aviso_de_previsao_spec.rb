require "rails_helper"

# Painel 3/4a–b: the cliente final's "previsão mudou", told by a move and by
# a virada — only a later day; and the deadline rule both share.
RSpec.describe AvisoDePrevisao do
  let(:pedido) { create(:pedido, tipo: "tecido") }
  let(:quarta) { Time.zone.parse("2026-11-04 15:30") }

  it "tells a later day, or no previsão any more, from no one when a virada tells it" do
    expect(described_class.call(pedido, de: quarta, para: quarta + 3.hours)).to be_nil
    evento = described_class.call(pedido, de: quarta, para: quarta + 1.day)

    expect([ evento.tipo, evento.recado, evento.user ]).to eq([ "previsao_mudou", "qua 04/11 → qui 05/11", nil ])
    expect(described_class.call(pedido, de: quarta, para: nil).recado).to eq("qua 04/11 → sem previsão")
  end

  it "needs a person for any other event" do
    expect(pedido.eventos_pedido.build(tipo: "devolvido", recado: "Falta a língua 35")).not_to be_valid
    expect(pedido.eventos_pedido.build(tipo: "previsao_mudou", recado: "qua 04/11 → qui 05/11")).to be_valid
  end

  it "says who comes to be late: on time before, past the deadline after" do
    prazo = quarta.to_date

    expect(described_class.passa_a_atrasar?(prazo, quarta, quarta + 1.day)).to be(true)
    expect(described_class.passa_a_atrasar?(prazo, quarta, nil)).to be(true)
    expect(described_class.passa_a_atrasar?(prazo, quarta - 1.day, quarta)).to be(false)
    expect(described_class.passa_a_atrasar?(prazo - 1, quarta, quarta + 1.day)).to be(false)
    expect(described_class.passa_a_atrasar?(nil, quarta, quarta + 1.day)).to be(false)
  end

  it "takes a reposição's deadline from its original" do
    original = create(:pedido, tipo: "tecido", prazo_entrega: Date.new(2026, 11, 12))

    expect(described_class.prazo(create(:pedido, tipo: "tecido", reposicao_de: original))).to eq(Date.new(2026, 11, 12))
  end
end
