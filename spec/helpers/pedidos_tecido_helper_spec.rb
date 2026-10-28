require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.7a (decided 16/10/2026): the tecido pedido page's widths, the
# warning past the paper and the fabric owner's balance.
RSpec.describe PedidosTecidoHelper, type: :helper do
  let(:client) { create(:client) }
  let(:tecido) { criar_tecido(largura: "1.80") }
  let(:pedido) { create(:pedido, client: client, tipo: "tecido") }

  before { def helper.cliente_final? = false }

  it "writes a width in meters" do
    expect([ helper.largura_em_metros(1600), helper.largura_em_metros(nil) ]).to eq([ "1,6 m", "—" ])
  end

  it "warns of a width past the default paper, never of one that fits" do
    (Empresa.atual || create(:empresa)).update!(largura_papel_mm: 1600)
    item = build(:item_pedido, materia_prima: tecido)
    expect(helper.aviso_de_largura(item)).to eq("Mais larga que o papel (1,6 m): confira se há papel para ela")
    item.largura_mm = 1500
    expect(helper.aviso_de_largura(item)).to be_nil
  end

  it "shows the balance of the pedido's fabric owner" do
    MovimentoEstoque.create!(materia_prima: tecido, client: client, tipo: "entrada", quantidade: 30)
    MovimentoEstoque.create!(materia_prima: tecido, da_empresa: true, tipo: "entrada", quantidade: 100)
    saldos = SaldosDeEstoque.call
    expect(helper.saldo_do_tecido(pedido, tecido, saldos)).to eq("30 m")
    pedido.dono_tecido = "empresa"
    expect(helper.saldo_do_tecido(pedido, tecido, saldos)).to eq("100 m")
  end

  # A cliente final sees only his own stock (Visibilidade): no empresa's balance.
  it "shows a cliente final no empresa balance, and nothing without client" do
    def helper.cliente_final? = true
    pedido.dono_tecido = "empresa"
    expect(helper.saldo_do_tecido(pedido, tecido, SaldosDeEstoque.call)).to be_nil
    expect(helper.saldo_do_tecido(build(:pedido, tipo: "tecido"), tecido, SaldosDeEstoque.call)).to be_nil
  end

  # Dublagem 1/5: a group that prints with ressalvas warns, never blocks.
  it "warns of a fabric whose group prints with ressalvas" do
    item = build(:item_pedido, materia_prima: tecido)
    expect(helper.aviso_de_ressalva(item)).to be_nil
    tecido.grupo_material.update!(estampavel: "ressalvas", ressalva: "a cor fica mais clara")
    expect(helper.aviso_de_ressalva(item)).to eq("Oxford estampa com ressalvas: a cor fica mais clara")
  end
end
