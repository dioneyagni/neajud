# Máquinas 4/5a (decided 24/11/2026): the baixa says the machine it was done
# on (Q4a; one per baixa, Q2a) — the old ones stay without, counted on the
# stage —; a baixa that contradicts a hold writes the machine movement it
# caused (Q1a); and each machine's trabalho may fix its typed speed over the
# measured one (Q4a, used from 4/5b).
class AdicionaMaquinaABaixa < ActiveRecord::Migration[8.1]
  def change
    add_reference :baixas_producao, :maquina, foreign_key: true, null: true
    add_reference :movimentos_da_fila, :baixa_producao, foreign_key: { to_table: :baixas_producao }, null: true
    add_column :trabalhos_da_maquina, :fixar_informado, :boolean, default: false, null: false
  end
end
