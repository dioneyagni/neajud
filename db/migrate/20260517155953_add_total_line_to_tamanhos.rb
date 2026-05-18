class AddTotalLineToTamanhos < ActiveRecord::Migration[8.1]
  def change
    add_column :tamanhos, :inner_lines_mm, :decimal
    add_column :tamanhos, :total_line_mm, :decimal
  end
end
