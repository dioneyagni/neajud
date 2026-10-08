# Etapa 2.2 (3/3, decided 07/10/2026): the pedido's cycle rascunho →
# confirmado → em_producao (on its first baixa) → entregue ("Marcar como
# entregue", which warns about what is left). When and by whom it was
# delivered; the status itself stays a string (Pedido::STATUS).
class AddEntregaToPedidos < ActiveRecord::Migration[8.1]
  def change
    add_column :pedidos, :entregue_em, :datetime
    add_reference :pedidos, :entregue_por, foreign_key: { to_table: :users }
  end
end
