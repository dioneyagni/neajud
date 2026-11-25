# Máquinas 2/5b (decided 21/11/2026, Q3a): a movement in the queue may send
# a stage to another machine — de_maquina the one it was on, para_maquina
# the one it is held on until it ends (nil with de_maquina: back to the
# automatic). Both nil: a move of place, as before. Only adds columns: the
# rows already there are moves of place.
class AdicionaMaquinasAoMovimentoDaFila < ActiveRecord::Migration[8.1]
  def change
    add_reference :movimentos_da_fila, :de_maquina, foreign_key: { to_table: :maquinas }, null: true
    add_reference :movimentos_da_fila, :para_maquina, foreign_key: { to_table: :maquinas }, null: true
  end
end
