# History of an arte being linked to a modelo/peça from a pedido's pending
# piece ("Escolher arte"), including moves from another modelo. Modelo names
# are copied so the history stays readable after a modelo is deleted.
class CreateArquivoVinculoLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :arquivo_vinculo_logs do |t|
      t.references :arquivo, null: false, foreign_key: true
      t.references :from_modelo, null: true, foreign_key: { to_table: :modelos }
      t.string :from_modelo_nome
      t.references :to_modelo, null: true, foreign_key: { to_table: :modelos }
      t.string :to_modelo_nome, null: false
      t.references :peca, null: true, foreign_key: true
      t.references :pedido, null: true, foreign_key: true
      t.string :changed_by
      t.timestamps
    end
  end
end
