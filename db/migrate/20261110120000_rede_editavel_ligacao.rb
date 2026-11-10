# Rede editável 2/2a (decided 09-10/11/2026): a ligação goes to the trash
# like the other records (Q5a: Excluivel's columns), and every save leaves a
# line in its histórico (Q3a: alteracoes_da_rede, the text of what changed,
# written when saved). The registro is polymorphic: the situações join it in
# 2/2b. No data to move: both start empty.
class RedeEditavelLigacao < ActiveRecord::Migration[8.1]
  def change
    change_table :ligacoes_dublagem, bulk: true do |t|
      t.datetime :deleted_at
      t.integer :deleted_by_id
      t.datetime :restored_at
      t.integer :restored_by_id
      t.index :deleted_at
    end

    create_table :alteracoes_da_rede do |t|
      t.string :uuid, null: false, index: { unique: true }
      t.references :registro, polymorphic: true, null: false
      # nil only outside a request (console, specs).
      t.references :user, foreign_key: true
      t.text :texto, null: false
      t.timestamps
    end
  end
end
