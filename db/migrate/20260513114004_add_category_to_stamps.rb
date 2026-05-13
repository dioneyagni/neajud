class AddCategoryToStamps < ActiveRecord::Migration[8.1]
  def change
    add_column :stamps, :category, :string
    add_column :stamps, :category_notes, :text
  end
end
