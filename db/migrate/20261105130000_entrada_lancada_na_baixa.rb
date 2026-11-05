# Decided 05/11/2026: whoever gives a baixa knows the material came in and
# launches the missing entry there (EntradaDaFaltaNaBaixa). The entry keeps
# counting if the baixa is undone — the material arrived either way — so it
# points at the baixa by lancada_na_baixa, not baixa_producao (which stops a
# movement counting, MovimentoEstoque.que_contam). Who launched it and, when
# they may not edit the stock, who authorized it with their password.
class EntradaLancadaNaBaixa < ActiveRecord::Migration[8.1]
  def change
    add_reference :movimento_estoques, :lancada_na_baixa, foreign_key: { to_table: :baixas_producao }
    add_reference :movimento_estoques, :lancado_por, foreign_key: { to_table: :users }
    add_reference :movimento_estoques, :autorizado_por, foreign_key: { to_table: :users }
  end
end
