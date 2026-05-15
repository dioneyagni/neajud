class CreateTamanhos < ActiveRecord::Migration[8.1]
  def change
    create_table :tamanhos do |t|
      t.references :stamp, null: false, foreign_key: true
      t.string :nome, null: false
      t.integer :position
      t.decimal :width_mm, precision: 10, scale: 2
      t.decimal :height_mm, precision: 10, scale: 2
      t.decimal :area_mm2, precision: 10, scale: 2
      t.timestamps
    end
  end
end
