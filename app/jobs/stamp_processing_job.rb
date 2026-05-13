require "shellwords"

class StampProcessingJob < ApplicationJob
  queue_as :default

  def perform(version_id)
    version = StampVersion.find(version_id)
    version.update!(status: :processing)

    validate_format!(version)
    detect_spots(version)
    extract_metadata(version)
    process_image(version) if preview_enabled?(version)

    version.update!(status: :processed)
  rescue StandardError => e
    version.update!(status: :failed)
    Rails.logger.error "[StampProcessingJob] Failed version #{version_id}: #{e.message}"
  end

  private

  def validate_format!(version)
    ext = version.extension.downcase
    unless Stamp::SUPPORTED_EXTENSIONS.include?(ext)
      version.update!(status: :unsupported_format)
      raise "Unsupported format: #{ext}"
    end
  end

  def detect_spots(version)
    return unless FileCategory.spot_detection_enabled?(version.category) &&
      FileCategory.for_extension(version.extension) == version.category

    input_path = version.original_path
    return unless File.exist?(input_path)

    result = `exiftool -s3 -AlphaChannelsNames #{Shellwords.escape(input_path)} 2>/dev/null`.strip
    names = result.split(",").map(&:strip).reject(&:empty?)
    real_spots = names.reject { |n| n == "Transparency" }
    version.update!(has_spots: real_spots.any?)
  end

  def extract_metadata(version)
    input_path = version.original_path
    return unless File.exist?(input_path)

    src = Shellwords.escape("#{input_path}[0]")

    dims = `identify -format '%w %h\\n' #{src} 2>/dev/null`.strip.split
    dpi_raw = `identify -format '%x %y\\n' #{src} 2>/dev/null`.strip.split
    cs = `identify -ping -format '%[colorspace]\\n' #{src} 2>/dev/null`.strip
    icc = extract_icc_name(input_path)
    other_raw = `identify -format '%[compression]|%[depth]|%[channels]\\n' #{src} 2>/dev/null`.strip.split("|")

    version.update!(
      colorspace: cs.presence,
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

  def process_image(version)
    input_path = version.original_path
    return unless File.exist?(input_path)

    output_dir = File.join(version.storage_dir, "preview")
    FileUtils.mkdir_p(output_dir)
    preview_path = File.join(output_dir, "preview.png")

    extension = version.extension.downcase
    if version.has_spots? && %w[tif tiff].include?(extension)
      generate_preview_utif(input_path, preview_path)
    elsif version.colorspace == "CMYK"
      generate_preview_cmyk(input_path, preview_path)
    else
      generate_preview_rgb(input_path, preview_path)
    end

    raise("Preview file not created") unless File.exist?(preview_path)
    version.update!(preview_file: preview_path.to_s)
  end

  def generate_preview_rgb(input, output)
    system("convert", "#{input}[0]",
           "-resize", "1200x1200>",
           "-define", "png:color-type=6",
           output.to_s) || raise("ImageMagick command failed")
  end

  def generate_preview_cmyk(input, output)
    system("convert", "#{input}[0]",
           "-profile", Rails.root.join("config", "icc", "USWebCoatedSWOP.icc").to_s,
           "-profile", Rails.root.join("config", "icc", "sRGB.icc").to_s,
           "-define", "png:color-type=6",
           output.to_s) || raise("ImageMagick command failed")
  end

  def generate_preview_utif(input, output)
    system("node", Rails.root.join("bin", "generate-preview.js").to_s, input, output) || raise("UTIF preview failed")
  end

  def preview_enabled?(version)
    FileCategory.preview_enabled?(version.category)
  end
end
