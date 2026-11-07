# Painel 3/4a (decided 07/11/2026, Q1a): the programação keeps only what a
# person changes — a stage moved in its sector's queue — and the queue goes
# on being computed. Never deleted: it is the history of the programação.
class MovimentosDaFila < ActiveRecord::Migration[8.1]
  def change
    create_table :movimentos_da_fila do |t|
      t.string :uuid, null: false
      t.references :pedido, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :etapa, null: false
      t.string :setor, null: false
      t.integer :de
      t.integer :para
      # The stage sorts as if it had arrived then; nil: back to its arrival.
      t.datetime :ordem_em, precision: 6
      t.text :motivo
      # [{ "pedido_id", "de", "para" }] — the previsões it made worse.
      t.json :empurrados, null: false, default: []
      t.timestamps
    end
    add_index :movimentos_da_fila, :uuid, unique: true
    add_index :movimentos_da_fila, [ :pedido_id, :etapa, :id ]
  end
end
