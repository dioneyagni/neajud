class CreateGrupoMateriais < ActiveRecord::Migration[8.1]
  def change
    create_table :grupo_materiais do |t|
      t.string :nome, null: false

      t.timestamps
    end
    add_index :grupo_materiais, :nome, unique: true
  end
end
