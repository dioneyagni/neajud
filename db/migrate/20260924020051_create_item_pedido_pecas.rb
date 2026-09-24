# One row per piece (lateral, língua…) of the modelo an ItemPedido orders:
# arquivo_id nil = pending (no arte yet), incluida false = unchecked (the
# pedido goes to production without that piece).
class CreateItemPedidoPecas < ActiveRecord::Migration[8.1]
  # Existing items become a single row with their own arte, so the pedido page
  # shows exactly what it showed before. The peça mirrors Arquivo#resolved_peca
  # (the corte's peça via tamanho, else the arte's own peca_id). Plain SQL so
  # this migration never depends on model code. Idempotent: skips items that
  # already have rows. Exercised by spec/db/create_item_pedido_pecas_spec.rb.
  BACKFILL_SQL = <<~SQL.freeze
    INSERT INTO item_pedido_pecas (item_pedido_id, arquivo_id, peca_id, incluida, position, created_at, updated_at)
    SELECT ip.id, a.id, COALESCE(corte.peca_id, a.peca_id), 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM itens_pedido ip
    JOIN arquivos a ON a.id = ip.arquivo_id
    LEFT JOIN tamanhos t ON t.id = a.tamanho_id
    LEFT JOIN arquivos corte ON corte.id = t.arquivo_id
    WHERE NOT EXISTS (SELECT 1 FROM item_pedido_pecas ipp WHERE ipp.item_pedido_id = ip.id)
  SQL

  def up
    create_table :item_pedido_pecas do |t|
      t.references :item_pedido, null: false, foreign_key: { to_table: :itens_pedido }
      t.references :arquivo, null: true, foreign_key: true
      t.references :peca, null: true, foreign_key: true
      t.boolean :incluida, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :item_pedido_pecas, %i[item_pedido_id peca_id], unique: true

    execute BACKFILL_SQL
  end

  def down
    drop_table :item_pedido_pecas
  end
end
