class AddMetadataJsonToStamps < ActiveRecord::Migration[8.1]
  def change
    add_column :stamps, :metadata, :json, default: {}
  end
end
