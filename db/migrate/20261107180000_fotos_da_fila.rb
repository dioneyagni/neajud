# Painel 3/4b (decided 07/11/2026, Q1a–Q7a): a photo of the whole queue at
# the start of each turno (FotoDaFila, its stages in VezDaFoto) — what was
# programmed, to tell "veio de · adiada N turnos", a load over 100% and the
# pedidos that came to be late at the virada. Photos older than 7 days are
# deleted (derived data); the virada's record per pedido (ViradaDoPedido)
# never is: it is the history of the programação. The virada writes the
# cliente final's "previsão mudou" with no person behind it, so an event's
# user becomes optional.
class FotosDaFila < ActiveRecord::Migration[8.1]
  def change
    create_table :fotos_da_fila do |t|
      t.string :uuid, null: false
      t.references :turno, null: false, foreign_key: true
      t.date :data, null: false
      t.datetime :inicio, null: false
      t.datetime :fim, null: false
      t.timestamps
    end
    add_index :fotos_da_fila, :uuid, unique: true
    # One photo per turno and day: two runs of the job never both take it.
    add_index :fotos_da_fila, [ :turno_id, :data ], unique: true
    add_index :fotos_da_fila, :inicio

    create_table :vezes_da_foto do |t|
      t.references :foto_da_fila, null: false, foreign_key: { to_table: :fotos_da_fila, on_delete: :cascade }
      t.references :pedido, null: false, foreign_key: true
      t.string :etapa, null: false
      t.string :setor, null: false
      t.integer :posicao
      # When the queue had the stage end (nil: no previsão) and the pedido's previsão.
      t.datetime :fim
      t.datetime :previsao
      # [{ "inicio", "fim" }] — its pieces in the turnos (ISO 8601).
      t.json :trechos, null: false, default: []
    end
    add_index :vezes_da_foto, [ :pedido_id, :etapa ]

    create_table :viradas_do_pedido do |t|
      t.string :uuid, null: false
      t.references :pedido, null: false, foreign_key: true
      # The turno it turned to, copied: the photo is deleted after 7 days.
      t.string :turno_nome, null: false
      t.date :data, null: false
      t.datetime :turno_fim, null: false
      t.datetime :de, null: false
      t.datetime :para
      t.boolean :passou_a_atrasar, null: false, default: false
      # [{ "pedido", "etapa", "veio_de", "veio_em" }] — the stages that didn't end.
      t.json :nao_terminaram, null: false, default: []
      t.timestamps
    end
    add_index :viradas_do_pedido, :uuid, unique: true
    add_index :viradas_do_pedido, :turno_fim

    change_column_null :eventos_pedido, :user_id, true
  end
end
