class CreateCorMateriais < ActiveRecord::Migration[8.1]
  def change
    create_table :cor_materiais do |t|
      t.string :nome, null: false

      t.timestamps
    end
    add_index :cor_materiais, :nome, unique: true
  end
end
