# Dublagem 5a (decided 03-04/11/2026, docs/plano.md Etapa 2.9 D1): an ordem
# de dublagem makes a construção's dublado for the stock when every ligação
# dubs before the estampa — gathering the missing meters of several pedidos.
# Generated with the meters to make, then done (the real meters: the layers
# and ligantes out, the dublado in, each movement pointing at it) or
# cancelled. Never deleted. client_id is the dublado's owner (the
# construção's), nil the empresa.
class OrdensDeDublagem < ActiveRecord::Migration[8.1]
  def change
    create_table :ordens_dublagem do |t|
      t.string :uuid, null: false, index: { unique: true }
      t.references :construcao, null: false, foreign_key: true
      t.references :client, foreign_key: true
      t.string :status, null: false, default: "gerada"
      t.decimal :metros, null: false
      t.decimal :metros_feitos
      t.references :gerada_por, foreign_key: { to_table: :users }
      t.references :feita_por, foreign_key: { to_table: :users }
      t.datetime :feita_em
      t.references :cancelada_por, foreign_key: { to_table: :users }
      t.datetime :cancelada_em
      t.timestamps
    end
    add_index :ordens_dublagem, :status

    add_reference :movimento_estoques, :ordem_dublagem, foreign_key: { to_table: :ordens_dublagem }
  end
end
