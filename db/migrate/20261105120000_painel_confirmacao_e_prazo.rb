# Painel 1/4 (decided 04/11/2026): when a pedido was confirmed, and by whom —
# the arrival order the Painel follows and the start it shows —, and the
# delivery date promised to the client. Pedidos confirmed before this stay
# without confirmado_em (the Painel falls back to their first baixa).
class PainelConfirmacaoEPrazo < ActiveRecord::Migration[8.1]
  def change
    add_column :pedidos, :confirmado_em, :datetime
    add_reference :pedidos, :confirmado_por, foreign_key: { to_table: :users }, null: true
    add_column :pedidos, :prazo_entrega, :date
  end
end
