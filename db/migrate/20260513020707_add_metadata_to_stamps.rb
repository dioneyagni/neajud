class AddMetadataToStamps < ActiveRecord::Migration[8.1]
  def change
    add_column :stamps, :icc_profile, :string
    add_column :stamps, :width_px, :integer
    add_column :stamps, :height_px, :integer
    add_column :stamps, :dpi, :float
  end
end
