# Painel 3/4b2 (decided 07/11/2026, Q8a): the faixa's dashed "was
# programmed" is each stage's first plan — the first photo (FotoDaFila)
# that had it after the confirmation. Photos go after 7 days, so the plan is
# kept apart, one row per pedido and stage, until 7 days after the delivery.
class PlanosDaEtapa < ActiveRecord::Migration[8.1]
  def change
    create_table :planos_da_etapa do |t|
      t.references :pedido, null: false, foreign_key: true
      t.string :etapa, null: false
      t.string :setor, null: false
      # When the photo had it end (nil: no previsão) and its pieces (ISO 8601).
      t.datetime :fim
      t.json :trechos, null: false, default: []
      # The photo it came from, copied: the photo is deleted after 7 days.
      t.string :turno_nome, null: false
      t.date :data, null: false
      t.timestamps
    end
    # Only the first plan: a later photo never replaces it.
    add_index :planos_da_etapa, [ :pedido_id, :etapa ], unique: true
  end
end
