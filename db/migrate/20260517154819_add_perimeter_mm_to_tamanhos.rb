class AddPerimeterMmToTamanhos < ActiveRecord::Migration[8.1]
  def change
    add_column :tamanhos, :perimeter_mm, :decimal
  end
end
