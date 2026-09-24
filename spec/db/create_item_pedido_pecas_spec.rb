require "rails_helper"
require Rails.root.join("db/migrate/20260924020051_create_item_pedido_pecas")

# The backfill runs once in production data; this checks the exact SQL the
# migration executes against rows shaped like pre-migration items.
RSpec.describe CreateItemPedidoPecas do
  def backfill!
    ActiveRecord::Base.connection.execute(described_class::BACKFILL_SQL)
  end

  it "gives each existing item one included row with its arte and the corte's peça" do
    lateral = create(:peca)
    arte = create(:arquivo, tamanho: create(:tamanho, arquivo: create(:arquivo, :corte, peca: lateral)))
    item = create(:item_pedido, arquivo: arte)
    backfill!
    expect(item.item_pedido_pecas.map { |r| [ r.arquivo, r.peca, r.estado ] }).to eq([ [ arte, lateral, :incluida ] ])
  end

  it "uses the arte's own peca_id when it has no tamanho, and nil when unknown" do
    lingua = create(:peca)
    with_peca = create(:item_pedido, arquivo: create(:arquivo, peca: lingua))
    without = create(:item_pedido)
    backfill!
    expect(with_peca.item_pedido_pecas.first.peca).to eq(lingua)
    expect(without.item_pedido_pecas.first.peca).to be_nil
  end

  it "is idempotent and leaves items that already have rows alone" do
    item = create(:item_pedido)
    create(:item_pedido_peca, item_pedido: item, incluida: false)
    2.times { backfill! }
    expect(item.item_pedido_pecas.reload.map(&:incluida)).to eq([ false ])
  end
end
