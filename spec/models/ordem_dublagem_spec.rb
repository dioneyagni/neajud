require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5a (decided 03-04/11/2026): an ordem makes a dublado for the
# stock — generated, then done (the layers and ligantes out from their
# owners, the dublado in) or cancelled.
RSpec.describe OrdemDublagem do
  let(:client) { create(:client, name: "Malharia Sul") }
  let(:oxford) { material_de_dublagem("Oxford", largura: "1.60 m") }
  let(:lona) { material_de_dublagem("Lona", largura: "1.40 m") }
  let(:filme) { material_de_dublagem("Filme", tipo: "filme", micras: 35) }
  let(:construcao) { montar_construcao([ oxford, "trama" ], [ lona, filme, { do_cliente: true } ], client: client).tap(&:save!) }
  let(:user) { create(:user) }

  def erros(ordem) = ordem.tap(&:validate).errors.full_messages

  def movimentos(ordem)
    ordem.movimentos_estoque.order(:id).map { |m| [ m.materia_prima.grupo_material.nome, m.materia_prima.tipo, m.client&.name, m.tipo, m.quantidade.to_f ] }
  end

  it "belongs to the construção's owner" do
    expect(described_class.create!(construcao: construcao, metros: 10).client).to eq(client)
  end

  it "done: each layer out from its owner and the ligante from the empresa, 1 m a meter, and the dublado in" do
    ordem = described_class.create!(construcao: construcao, metros: 10, gerada_por: user)
    ordem.marcar_feita!(metros: 9.5, user: user)

    expect([ ordem.status, ordem.metros_feitos.to_f, ordem.feita_por ]).to eq([ "feita", 9.5, user ])
    expect(movimentos(ordem)).to eq([ [ "Oxford", "tecido", nil, "saida", 9.5 ], [ "Lona", "tecido", "Malharia Sul", "saida", 9.5 ],
                                      [ "Filme", "filme", nil, "saida", 9.5 ], [ "Oxford", "dublado", "Malharia Sul", "entrada", 9.5 ] ])
  end

  # Decision 4a: a missing component never blocks — its balance goes negative.
  it "is done without the components in the stock" do
    described_class.create!(construcao: construcao, metros: 10).marcar_feita!(metros: 10, user: user)

    expect(SaldosDeEstoque.call.empresa(oxford)).to eq(-10)
  end

  it "cancelled, touches no stock; neither a done nor a cancelled ordem changes again" do
    ordem = described_class.create!(construcao: construcao, metros: 10)
    ordem.cancelar!(user: user)

    expect([ ordem.status, ordem.cancelada_por, ordem.movimentos_estoque.count ]).to eq([ "cancelada", user, 0 ])
    expect { ordem.marcar_feita!(metros: 10, user: user) }.to raise_error(ActiveRecord::RecordInvalid, /is cancelada: only a generated ordem can be marked done/)
  end

  it "refuses zero meters, and marking it done without the real ones" do
    expect(erros(described_class.new(construcao: construcao, metros: 0))).to include("Metros must be more than 0 m (got 0)")
    ordem = described_class.create!(construcao: construcao, metros: 10)
    expect { ordem.marcar_feita!(metros: nil, user: user) }.to raise_error(ActiveRecord::RecordInvalid, /Metros feitos must be more than 0 m/)
    expect(ordem.reload.movimentos_estoque).to be_empty
  end

  # A dublado dubbed after the estampa is the pedido's own (5b), never the stock's.
  it "refuses a construção that dubs after the estampa" do
    espuma = material_de_dublagem("Espuma", densidade: "D28")
    depois = montar_construcao([ oxford, "trama" ], [ espuma, nil ]).tap(&:save!)

    expect(erros(described_class.new(construcao: depois, metros: 5)).first).to include("doesn't dub wholly before the estampa (depois)")
  end
end
