# Decided 05/11/2026: whoever gives a baixa, or delivers the pedido, knows the
# material came in and launches the missing entry there (EntradaDaFalta). The
# entry keeps counting if the baixa is undone — the material arrived either
# way — so it points at the baixa by lancada_na_baixa, not baixa_producao
# (which stops a movement counting, MovimentoEstoque.que_contam), and at the
# delivered pedido by lancada_na_entrega, not pedido (a trashed pedido's
# movements stop counting). Who launched it and, when they may not edit the
# stock, who authorized it with their password.
class EntradaLancadaNaBaixa < ActiveRecord::Migration[8.1]
  def change
    add_reference :movimento_estoques, :lancada_na_baixa, foreign_key: { to_table: :baixas_producao }
    add_reference :movimento_estoques, :lancada_na_entrega, foreign_key: { to_table: :pedidos }
    add_reference :movimento_estoques, :lancado_por, foreign_key: { to_table: :users }
    add_reference :movimento_estoques, :autorizado_por, foreign_key: { to_table: :users }
  end
end
