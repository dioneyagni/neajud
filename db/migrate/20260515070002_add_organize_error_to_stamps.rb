class AddOrganizeErrorToStamps < ActiveRecord::Migration[8.1]
  def change
    add_column :stamps, :organize_error, :string
  end
end
