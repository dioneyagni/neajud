require "rails_helper"

# Etapa 2.8 (5/5): a client's draft between him and the factory.
RSpec.describe EnvioDoPedido do
  let(:user) { create(:user) }
  let(:pedido) { create(:pedido).tap { |p| p.itens_pedido.create!(arquivo: create(:arquivo)) } }

  it "sends a draft with items, pendências or not, and records it" do
    evento = described_class.enviar(pedido, user: user)
    expect(evento).to be_persisted.and have_attributes(tipo: "enviado", user: user)
    expect(pedido.reload.status).to eq("enviado")
  end

  it "refuses to send a draft without items, or one already sent" do
    expect(described_class.enviar(create(:pedido), user: user).errors[:base].join).to include("has no items")
    pedido.update!(status: "enviado")
    expect(described_class.enviar(pedido, user: user).errors[:base].join).to include("expected rascunho to be enviado")
  end

  it "takes a sent pedido back to a draft" do
    pedido.update!(status: "enviado")
    expect(described_class.retirar(pedido, user: user)).to be_persisted
    expect(pedido.reload.status).to eq("rascunho")
  end

  it "returns a sent pedido with the note, which the draft shows until sent again" do
    pedido.update!(status: "enviado")
    evento = described_class.devolver(pedido, user: user, recado: " Falta a língua 35 ")
    expect(evento).to be_persisted.and have_attributes(recado: "Falta a língua 35")
    expect(pedido.reload).to have_attributes(status: "rascunho", devolucao_pendente: evento)
    described_class.enviar(pedido, user: user)
    expect(pedido.reload.devolucao_pendente).to be_nil
  end

  it "refuses to return without a note, or a pedido that wasn't sent" do
    pedido.update!(status: "enviado")
    expect(described_class.devolver(pedido, user: user, recado: " ").errors[:recado]).to be_present
    expect(pedido.reload.status).to eq("enviado")
    pedido.update!(status: "confirmado")
    expect(described_class.devolver(pedido, user: user, recado: "x")).not_to be_persisted
  end

  it "never moves a frozen pedido" do
    pedido.update!(status: "enviado", grade_antiga: true)
    expect(described_class.retirar(pedido, user: user).errors[:base].join).to include("frozen")
    expect(pedido.reload.status).to eq("enviado")
  end
end
