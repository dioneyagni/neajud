require "shellwords"

class StampProcessingJob < ApplicationJob
  queue_as :default

  STORAGE_BASE = Rails.root.join("storage", "stamps")

  def perform(stamp_id)
    stamp = Stamp.find(stamp_id)
    stamp.update!(status: :processing)

    validate_format!(stamp)
    detect_spots(stamp)
    extract_metadata(stamp)
    process_image(stamp)

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

  def detect_spots(stamp)
    return unless %w[tif tiff psd].include?(stamp.extension.downcase)

    input_path = storage_path(stamp, "original", stamp.original_file)
    result = `exiftool -s3 -AlphaChannelsNames #{Shellwords.escape(input_path)} 2>/dev/null`.strip
    names = result.split(",").map(&:strip).reject(&:empty?)
    real_spots = names.reject { |n| n == "Transparency" }
    stamp.update!(has_spots: real_spots.any?)
  end

  def extract_metadata(stamp)
    input_path = storage_path(stamp, "original", stamp.original_file)
    src = Shellwords.escape("#{input_path}[0]")

    dims = `identify -format '%w %h\\n' #{src} 2>/dev/null`.strip.split
    dpi_raw = `identify -format '%x %y\\n' #{src} 2>/dev/null`.strip.split
    icc = extract_icc_name(input_path)
    other_raw = `identify -format '%[compression]|%[depth]|%[channels]\\n' #{src} 2>/dev/null`.strip.split("|")

    stamp.update!(
      icc_profile: icc.presence,
      width_px: dims[0].to_i,
      height_px: dims[1].to_i,
      dpi: dpi_raw[0].to_f,
      metadata: {
        compression: other_raw[0].presence,
        depth: other_raw[1].to_i > 0 ? other_raw[1].to_i : nil,
        channels: other_raw[2].presence,
        file_size: File.size(input_path)
      }.compact
    )
  end

  def extract_icc_name(path)
    src = Shellwords.escape("#{path}[0]")

    name = `identify -format '%[icc:description]\\n' #{src} 2>/dev/null`.strip
    return name unless name.blank?

    name = `identify -format '%[photoshop:ICCProfile]\\n' #{src} 2>/dev/null`.strip
    return name unless name.blank?

    verbose = `identify -verbose #{src} 2>/dev/null`
    name = verbose[/icc:description:\s*(.+)/, 1]
    return name.strip if name
    name = verbose[/photoshop:ICCProfile:\s*(.+)/, 1]
    return name.strip if name

    nil
  end

  def process_image(stamp)
    input_path = storage_path(stamp, "original", stamp.original_file)
    output_dir = storage_path(stamp, "preview")
    FileUtils.mkdir_p(output_dir)

    preview_path = File.join(output_dir, "preview.png")

    if stamp.has_spots?
      generate_preview_utif(input_path, preview_path)
    elsif stamp.colorspace == "CMYK"
      generate_preview_cmyk(input_path, preview_path)
    else
      generate_preview_rgb(input_path, preview_path)
    end

    raise("Preview file not created") unless File.exist?(preview_path)
    stamp.update!(preview_file: preview_path.to_s)
  end

  def generate_preview_rgb(input, output)
    system("convert", "#{input}[0]",
           "-resize", "1200x1200>",
           "-type", "TrueColorAlpha",
           output.to_s) || raise("ImageMagick command failed")
  end

  def generate_preview_cmyk(input, output)
    system("convert", "#{input}[0]",
           "-profile", Rails.root.join("config", "icc", "USWebCoatedSWOP.icc").to_s,
           "-profile", Rails.root.join("config", "icc", "sRGB.icc").to_s,
           "-type", "TrueColorAlpha",
           output.to_s) || raise("ImageMagick command failed")
  end

  def generate_preview_utif(input, output)
    system("node", Rails.root.join("bin", "generate-preview.js").to_s, input, output) || raise("UTIF preview failed")
  end

  def storage_path(stamp, type, filename = nil)
    path = File.join(STORAGE_BASE, stamp.uuid, type.to_s)
    FileUtils.mkdir_p(path) unless File.directory?(path)
    filename ? File.join(path, filename) : path
  end
end
