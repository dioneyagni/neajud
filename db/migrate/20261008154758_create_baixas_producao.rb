# Etapa 2.2 (2/3, decided 07/10/2026): the factory's baixa of a production
# stage — one line, a referência or the whole pedido at once — with the
# measure typed (metragem or pieces), what the files expected, and whether it
# was confirmed outside the warning band. `linhas` keeps the production lines
# it covered (keys built from uuids). desfeita_*: undoing comes in 3/3.
class CreateBaixasProducao < ActiveRecord::Migration[8.1]
  def change
    create_table :baixas_producao do |t|
      t.string :uuid, null: false
      t.references :pedido, null: false, foreign_key: true
      t.string :etapa, null: false
      t.string :nivel, null: false
      t.json :linhas, null: false, default: []
      t.decimal :medida, precision: 12, scale: 4, null: false
      t.decimal :esperado, precision: 12, scale: 4
      t.boolean :fora_da_faixa, null: false, default: false
      t.references :user, foreign_key: true
      t.string :changed_by
      t.datetime :desfeita_em
      t.references :desfeita_por, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :baixas_producao, :uuid, unique: true
    add_index :baixas_producao, [ :pedido_id, :etapa ]
  end
end
