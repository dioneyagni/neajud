class ExtractMetadataToNewTables < ActiveRecord::Migration[8.1]
  class MigrationStampVersion < ActiveRecord::Base
    self.table_name = "stamp_versions"
    has_many :migration_stamp_image_metadata, class_name: "ExtractMetadataToNewTables::MigrationStampImageMetadatum"
    has_many :migration_cut_layers, class_name: "ExtractMetadataToNewTables::MigrationCutLayer"
  end

  class MigrationStampImageMetadatum < ActiveRecord::Base
    self.table_name = "stamp_image_metadata"
    belongs_to :migration_stamp_version, class_name: "ExtractMetadataToNewTables::MigrationStampVersion",
               foreign_key: :stamp_version_id
  end

  class MigrationCutLayer < ActiveRecord::Base
    self.table_name = "cut_layers"
    belongs_to :migration_stamp_version, class_name: "ExtractMetadataToNewTables::MigrationStampVersion",
               foreign_key: :stamp_version_id
  end

  def up
    MigrationStampVersion.where(category: "artes").find_each do |version|
      next unless image_columns.any? { |c| version.read_attribute(c).present? }
      MigrationStampImageMetadatum.create!(
        stamp_version_id: version.id,
        colorspace: version.read_attribute(:colorspace),
        colorspace_error: version.read_attribute(:colorspace_error),
        icc_profile: version.read_attribute(:icc_profile),
        has_spots: version.read_attribute(:has_spots),
        width_px: version.read_attribute(:width_px),
        height_px: version.read_attribute(:height_px),
        dpi: version.read_attribute(:dpi),
        metadata: version.read_attribute(:metadata)
      )
    end

    MigrationStampVersion.where.not(layer_annotations: nil).find_each do |version|
      layers = version.read_attribute(:layer_annotations)
      next unless layers.is_a?(Array)
      layers.each_with_index do |layer, idx|
        MigrationCutLayer.create!(
          stamp_version_id: version.id,
          layer_name: layer["layer_name"],
          color: layer["color"],
          annotation: layer["annotation"] || "cut",
          position: idx
        )
      end
    end

    remove_column :stamp_versions, :colorspace
    remove_column :stamp_versions, :colorspace_error
    remove_column :stamp_versions, :icc_profile
    remove_column :stamp_versions, :has_spots
    remove_column :stamp_versions, :width_px
    remove_column :stamp_versions, :height_px
    remove_column :stamp_versions, :dpi
    remove_column :stamp_versions, :metadata
    remove_column :stamp_versions, :layer_annotations

    remove_column :stamps, :original_file
    remove_column :stamps, :preview_file
    remove_column :stamps, :overlay_file
    remove_index :stamps, column: :status if index_exists?(:stamps, :status)
    remove_column :stamps, :status
    remove_column :stamps, :colorspace
    remove_column :stamps, :icc_profile
    remove_column :stamps, :has_spots
    remove_column :stamps, :width_px
    remove_column :stamps, :height_px
    remove_column :stamps, :dpi
    remove_column :stamps, :metadata
  end

  def down
    add_column :stamps, :metadata, :json, default: {}
    add_column :stamps, :dpi, :float
    add_column :stamps, :height_px, :integer
    add_column :stamps, :width_px, :integer
    add_column :stamps, :has_spots, :boolean, default: false
    add_column :stamps, :icc_profile, :string
    add_column :stamps, :colorspace, :string
    add_column :stamps, :status, :string, default: "pending"
    add_index :stamps, :status
    add_column :stamps, :overlay_file, :string
    add_column :stamps, :preview_file, :string
    add_column :stamps, :original_file, :string

    add_column :stamp_versions, :layer_annotations, :json
    add_column :stamp_versions, :metadata, :json
    add_column :stamp_versions, :dpi, :float
    add_column :stamp_versions, :height_px, :integer
    add_column :stamp_versions, :width_px, :integer
    add_column :stamp_versions, :has_spots, :boolean, default: false
    add_column :stamp_versions, :icc_profile, :string
    add_column :stamp_versions, :colorspace_error, :string
    add_column :stamp_versions, :colorspace, :string

    MigrationStampImageMetadatum.find_each do |meta|
      next unless meta.migration_stamp_version
      meta.migration_stamp_version.update_columns(
        colorspace: meta.colorspace,
        colorspace_error: meta.colorspace_error,
        icc_profile: meta.icc_profile,
        has_spots: meta.has_spots,
        width_px: meta.width_px,
        height_px: meta.height_px,
        dpi: meta.dpi,
        metadata: meta.metadata
      )
    end

    MigrationCutLayer.order(:stamp_version_id, :position).group_by(&:migration_stamp_version).each do |version, layers|
      next unless version
      version.update_columns(
        layer_annotations: layers.map { |l| { "layer_name" => l.layer_name, "color" => l.color, "annotation" => l.annotation } }
      )
    end
  end

  private

  def image_columns
    %i[colorspace colorspace_error icc_profile has_spots width_px height_px dpi metadata]
  end
end
