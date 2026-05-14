class AddLayerAnnotationsToStampVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :stamp_versions, :layer_annotations, :json
  end
end
