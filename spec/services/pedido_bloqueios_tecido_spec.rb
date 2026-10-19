require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.7a (decided 16/10/2026): what keeps a tecido draft from being
# confirmed — the client the pedido's, each item's fabric, meters and width.
RSpec.describe PedidoBloqueiosTecido do
  let(:client) { create(:client) }
  let(:pedido) { create(:pedido, client: client, tipo: "tecido") }
  let(:empresa) { Empresa.atual || create(:empresa) }
  # Etapa 2.7b: priced, so only what each example is about shows.
  before { empresa.update!(preco_impressao_metro_tecido: 15) }

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
    empresa.update!(largura_papel_mm: 1000)
    item(criar_obra_de_tecido("corrida", client: client), materia_prima: criar_tecido(largura: "1.80"))
    expect(described_class.call(pedido)).to be_empty
  end

  it "leaves the width and the client to the factory, the fabric and meters to the client" do
    expect(PedidoBloqueiosService::DA_FABRICA).to include(:sem_largura, :pedido_sem_cliente, :arte_de_outro_cliente)
    expect(PedidoBloqueiosService::DA_FABRICA).not_to include(:sem_material, :zerado)
  end

  # Etapa 2.7b (decided 17/10/2026): the minimum is per item, his to raise
  # (Q5) or the team's to approve for those meters (Q2).
  it "names an item below the minimum until approved for its meters" do
    empresa.update!(metragem_minima_tecido: 10)
    curto = item(criar_obra_de_tecido("corrida", client: client), metros: 4)
    item(criar_obra_de_tecido("corrida", client: client), metros: 10)
    expect(described_class.call(pedido).map(&:descricao)).to eq([ "#{curto.arte.titulo} abaixo do mínimo: 4 m de 10 m" ])
    curto.aprovar_minimo!(create(:user))
    expect(described_class.call(pedido)).to be_empty
    curto.update!(metros: 4.5)
    expect(described_class.call(pedido).map(&:tipo)).to eq(%i[abaixo_do_minimo])
    expect(PedidoBloqueiosService::DA_FABRICA).not_to include(:abaixo_do_minimo)
  end

  it "names the print without a price, and the empresa's fabric without its material's" do
    empresa.update!(preco_impressao_metro_tecido: nil)
    sem_preco = criar_tecido(grupo: "Linho")
    item(criar_obra_de_tecido("corrida", client: client), materia_prima: sem_preco)
    expect(described_class.call(pedido).map(&:tipo)).to eq(%i[sem_preco_impressao])
    pedido.update!(dono_tecido: "empresa")
    expect(described_class.call(pedido).map(&:descricao).last).to eq("#{pedido.itens_pedido.first.arte.titulo}: o tecido #{sem_preco.nome_completo} sem preço por metro")
    expect(PedidoBloqueiosService::DA_FABRICA).to include(:sem_preco_impressao, :sem_preco_tecido)
  end
end
