class BackfillStampVersions < ActiveRecord::Migration[8.1]
  class Stamp < ActiveRecord::Base
    self.table_name = "stamps"
  end

  class StampVersion < ActiveRecord::Base
    self.table_name = "stamp_versions"
  end

  def up
    Stamp.find_each do |stamp|
      next if stamp.original_file.blank?

      version_dir = File.join(Rails.root, "storage", "stamps", stamp.uuid, "v1")
      new_original_dir = File.join(version_dir, "original")
      new_preview_dir = File.join(version_dir, "preview")

      FileUtils.mkdir_p(new_original_dir)
      FileUtils.mkdir_p(new_preview_dir)

      old_original = File.join(Rails.root, "storage", "stamps", stamp.uuid, "original", stamp.original_file)
      old_preview = File.join(Rails.root, "storage", "stamps", stamp.uuid, "preview", "preview.png")

      if File.exist?(old_original)
        FileUtils.cp(old_original, File.join(new_original_dir, stamp.original_file))
      end

      if File.exist?(old_preview)
        FileUtils.cp(old_preview, File.join(new_preview_dir, "preview.png"))
      end

      new_preview_path = File.join(new_preview_dir, "preview.png")

      version = StampVersion.create!(
        stamp_id: stamp.id,
        version_number: 1,
        uuid: SecureRandom.uuid,
        filename: stamp.filename,
        extension: stamp.extension,
        mime_type: stamp.mime_type,
        original_file: stamp.original_file,
        preview_file: (new_preview_path if File.exist?(new_preview_path)),
        status: stamp.read_attribute(:status),
        approved: true,
        colorspace: stamp.read_attribute(:colorspace),
        has_spots: stamp.read_attribute(:has_spots) || false,
        icc_profile: stamp.read_attribute(:icc_profile),
        width_px: stamp.read_attribute(:width_px),
        height_px: stamp.read_attribute(:height_px),
        dpi: stamp.read_attribute(:dpi),
        category: stamp.category,
        category_notes: stamp.read_attribute(:category_notes),
        metadata: stamp.read_attribute(:metadata)
      )
      stamp.update_column(:approved_version_id, version.id)
    end
  end

  def down
    Stamp.update_all(approved_version_id: nil)
    StampVersion.delete_all
  end
end
