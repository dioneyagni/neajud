require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.3d2 (decided 19/10/2026): per material × owner, the entries cover
# the oldest outs first; a pedido whose out passes them waits, missing the
# difference. Computed on the fly.
RSpec.describe AguardandoMaterial do
  let(:oxford) { criar_tecido }
  let(:client) { create(:client) }
  let(:primeiro) { create(:pedido, status: "confirmado", client: client) }
  let(:segundo) { create(:pedido, status: "confirmado", client: client) }

  def movimento(tipo, quantidade, pedido: nil, cliente: nil, quando: Time.current)
    MovimentoEstoque.create!(materia_prima: oxford, client: cliente, da_empresa: cliente.nil?, tipo: tipo, quantidade: quantidade, pedido: pedido, created_at: quando)
  end

  def faltas(pedido) = described_class.call.do_pedido(pedido).map { |f| [ f.materia_prima, f.client, f.metros ] }

  before do
    movimento("entrada", 10, quando: 3.days.ago)
    movimento("saida", 6, pedido: primeiro, quando: 2.days.ago)
    movimento("saida", 6, pedido: segundo, quando: 1.day.ago)
  end

  it "covers the oldest out first: the later pedido waits for what passes the entries" do
    expect([ faltas(primeiro), faltas(segundo) ]).to eq([ [], [ [ oxford, nil, 2.0 ] ] ])
    expect(described_class.call.pedido_ids).to eq([ segundo.id ])
    expect(described_class.call.do_material(oxford).map(&:pedido_id)).to eq([ segundo.id ])
  end

  it "clears by itself with an entry, and counts an out by hand in its order" do
    movimento("entrada", 2)
    expect(faltas(segundo)).to eq([])
    movimento("saida", 1)
    expect(faltas(segundo)).to eq([]) # made after the pedido's: it takes what is left
  end

  it "keeps each owner apart: the client's material doesn't cover the empresa's" do
    movimento("entrada", 50, cliente: client)
    movimento("saida", 3, pedido: primeiro, cliente: create(:client))
    expect(faltas(primeiro).map(&:last)).to eq([ 3.0 ])
  end

  it "stops counting a trashed pedido's out, and no longer shows a delivered one" do
    primeiro.excluir!(changed_by: "127.0.0.1")
    expect(faltas(segundo)).to eq([])
    primeiro.restaurar!(changed_by: "127.0.0.1")
    segundo.update!(status: "entregue")
    expect(described_class.call.pedido_ids).to eq([])
  end
end
