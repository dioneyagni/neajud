require "shellwords"

class StampProcessingJob < ApplicationJob
  queue_as :default

  STORAGE_BASE = Rails.root.join("storage", "stamps")

  def perform(stamp_id)
    stamp = Stamp.find(stamp_id)
    stamp.update!(status: :processing)

    validate_format!(stamp)
    process_image(stamp)
    detect_spots(stamp)

    stamp.update!(status: :processed)
  rescue StandardError => e
    stamp.update!(status: :failed)
    Rails.logger.error "[StampProcessingJob] Failed stamp #{stamp_id}: #{e.message}"
  end

  private

  def validate_format!(stamp)
    ext = stamp.extension.downcase
    unless Stamp::SUPPORTED_EXTENSIONS.include?(ext)
      stamp.update!(status: :unsupported_format)
      raise "Unsupported format: #{ext}"
    end
  end

  def process_image(stamp)
    input_path = storage_path(stamp, "original", stamp.original_file)
    output_dir = storage_path(stamp, "preview")
    FileUtils.mkdir_p(output_dir)

    preview_path = File.join(output_dir, "preview.png")

    cmd = build_convert_command(input_path, preview_path, stamp)
    system(cmd) || raise("ImageMagick command failed: #{cmd}")

    stamp.update!(preview_file: preview_path.to_s)
  end

  def build_convert_command(input, output, stamp)
    if stamp.colorspace == "CMYK"
      "convert #{Shellwords.escape(input)} -colorspace sRGB -type TrueColorAlpha #{Shellwords.escape(output)}"
    else
      "convert #{Shellwords.escape(input)} -resize 1200x1200\\> -type TrueColorAlpha #{Shellwords.escape(output)}"
    end
  end

  def detect_spots(stamp)
    return unless %w[tif tiff psd].include?(stamp.extension.downcase)

    input_path = storage_path(stamp, "original", stamp.original_file)
    result = `identify -verbose #{Shellwords.escape(input_path)}`

    if result.include?("Channel")
      spot_channels = result.scan(/Channel (\w+):/).flatten
      cmyk_channels = %w[Cyan Magenta Yellow Black]
      non_cmyk = spot_channels.reject { |c| cmyk_channels.include?(c) || c =~ /^(Gray|Alpha|Red|Green|Blue)$/ }
      stamp.update!(has_spots: non_cmyk.any?)
    end
  end

  def storage_path(stamp, type, filename = nil)
    path = File.join(STORAGE_BASE, stamp.uuid, type.to_s)
    FileUtils.mkdir_p(path) unless File.directory?(path)
    filename ? File.join(path, filename) : path
  end
end
