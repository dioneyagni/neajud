class CreateArquivoModelos < ActiveRecord::Migration[8.1]
  def change
    create_table :arquivo_modelos do |t|
      t.references :arquivo, null: false, foreign_key: true
      t.references :modelo, null: false, foreign_key: true

      t.timestamps
    end

    add_index :arquivo_modelos, %i[arquivo_id modelo_id], unique: true
  end
end
