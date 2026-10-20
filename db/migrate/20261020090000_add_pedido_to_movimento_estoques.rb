# Etapa 2.3d2 (decided 19/10/2026): a pedido's stock outs are movements of
# their own, pointing at it — a trashed pedido stops counting, and the
# movements list links to it. Earlier movements stay without pedido
# (decided 20/10/2026: no outs backfilled for pedidos confirmed before).
class AddPedidoToMovimentoEstoques < ActiveRecord::Migration[8.1]
  def change
    add_reference :movimento_estoques, :pedido, foreign_key: true, null: true
  end
end
