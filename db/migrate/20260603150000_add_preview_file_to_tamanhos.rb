class AddPreviewFileToTamanhos < ActiveRecord::Migration[8.1]
  def change
    add_column :tamanhos, :preview_file, :string
  end
end
