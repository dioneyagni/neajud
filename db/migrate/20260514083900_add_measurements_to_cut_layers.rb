class AddMeasurementsToCutLayers < ActiveRecord::Migration[8.1]
  def change
    change_table :cut_layers, bulk: true do |t|
      t.decimal :width_mm, precision: 10, scale: 2
      t.decimal :height_mm, precision: 10, scale: 2
      t.decimal :perimeter_mm, precision: 10, scale: 2
      t.decimal :area_mm2, precision: 10, scale: 2
    end
  end
end
