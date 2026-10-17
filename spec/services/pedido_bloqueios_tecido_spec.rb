require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.7a (decided 16/10/2026): what keeps a tecido draft from being
# confirmed — the client the pedido's, each item's fabric, meters and width.
RSpec.describe PedidoBloqueiosTecido do
  let(:client) { create(:client) }
  let(:pedido) { create(:pedido, client: client, tipo: "tecido") }

  def item(arte, materia_prima: criar_tecido, metros: 1)
    create(:item_pedido, pedido: pedido, arquivo: arte.arquivos.first, materia_prima: materia_prima, metros: metros)
  end

  it "has nothing to say about a complete item, the catálogo's of another client too" do
    item(criar_obra_de_tecido("corrida", client: client))
    item(criar_obra_de_tecido("cor_lisa", client: create(:client)))
    expect(described_class.call(pedido)).to be_empty
  end

  it "names each item's missing fabric, meters or width, in that order" do
    item(criar_obra_de_tecido("corrida", client: client), materia_prima: nil, metros: nil)
    item(criar_obra_de_tecido("corrida", client: client), materia_prima: criar_tecido(largura: "?", grupo: "Linho"))
    expect(described_class.call(pedido).map(&:tipo)).to eq(%i[sem_material zerado sem_largura])
  end

  # Decided 16/10/2026: a wider paper may exist — only a warning on the page.
  it "never blocks a width past the paper" do
    (Empresa.atual || create(:empresa)).update!(largura_papel_mm: 1000)
    item(criar_obra_de_tecido("corrida", client: client), materia_prima: criar_tecido(largura: "1.80"))
    expect(described_class.call(pedido)).to be_empty
  end

  it "leaves the width and the client to the factory, the fabric and meters to the client" do
    expect(PedidoBloqueiosService::DA_FABRICA).to include(:sem_largura, :pedido_sem_cliente, :arte_de_outro_cliente)
    expect(PedidoBloqueiosService::DA_FABRICA).not_to include(:sem_material, :zerado)
  end
end
