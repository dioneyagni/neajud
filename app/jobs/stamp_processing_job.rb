require "shellwords"
require "set"

class StampProcessingJob < ApplicationJob
  queue_as :default

  def perform(version_id)
    version = StampVersion.find(version_id)
    version.update!(status: :processing)

    validate_format!(version)
    detect_spots(version)
    extract_metadata(version)
    process_image(version) if preview_enabled?(version) || version.extension.downcase == "dxf"
    extract_cut_layers_from_preview(version)
    measure_cut_layers(version)
    organize_dxf(version)

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
    meta = version.image_metadata || version.build_image_metadata
    meta.update!(has_spots: real_spots.any?)
  end

  def extract_cut_layers_from_preview(version)
    preview_path = version.preview_file
    return unless preview_path && File.exist?(preview_path)

    colors = case version.extension.downcase
    when "dxf" then extract_colors_from_svg(preview_path)
    else return
    end

    return if colors.blank?

    version.cut_layers.destroy_all
    colors.each_with_index do |color, idx|
      version.cut_layers.create!(
        layer_name: "Camada #{idx + 1}",
        color: color,
        annotation: "cut",
        position: idx
      )
    end
  end

  def measure_cut_layers(version)
    DxfMeasurementService.call(version)
  end

  def organize_dxf(version)
    return unless version.extension.downcase == "dxf"

    DxfOrganizationService.call(version.stamp)
  end

  def extract_colors_from_svg(path)
    svg = File.read(path)
    colors = Set.new

    # Match strokes on drawing <g> groups (those wrapping <path> elements).
    # Pattern: <g stroke="..."> optionally followed by <g><path, <path, etc.
    # This excludes container <g> whose stroke is inherited but never rendered.
    svg.scan(/<g stroke="(#[^"]*|rgb\([^)]*\))">(?:<g>)?<(?:path|polyline|line|rect|circle|ellipse|polygon)\b/) do
      match = Regexp.last_match[1]
      hex = if match.start_with?("#")
              match.upcase
      elsif match.start_with?("rgb(")
              m = match.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/)
              "#%02X%02X%02X" % [ m[1].to_i, m[2].to_i, m[3].to_i ] if m
      end
      colors << hex if hex
    end

    colors.to_a
  end

  def extract_metadata(version)
    input_path = version.original_path
    return unless File.exist?(input_path)

    extra = {}
    if version.extension.downcase == "dxf"
      extra.merge!(extract_dxf_header_info(input_path))
    end

    src = Shellwords.escape("#{input_path}[0]")

    dims = `identify -format '%w %h\\n' #{src} 2>/dev/null`.strip.split
    dpi_raw = `identify -format '%x %y\\n' #{src} 2>/dev/null`.strip.split
    cs = `identify -ping -format '%[colorspace]\\n' #{src} 2>/dev/null`.strip
    icc = extract_icc_name(input_path)
    other_raw = `identify -format '%[compression]|%[depth]|%[channels]\\n' #{src} 2>/dev/null`.strip.split("|")

    meta = version.image_metadata || version.build_image_metadata
    meta.update!(
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
      }.compact.merge(extra)
    )
  end

  def extract_dxf_header_info(path)
    lines = File.readlines(path, encoding: "ISO-8859-1", fallback: "UTF-8").map(&:strip)
    header = {}
    inside = false
    i = 0
    while i < lines.length - 1
      group_code = lines[i]
      value = lines[i + 1]

      if !inside && group_code == "0" && value == "SECTION"
        if i + 3 < lines.length && lines[i + 2] == "2" && lines[i + 3] == "HEADER"
          inside = true
          i += 4
        else
          i += 2
        end
        next
      end

      if inside && group_code == "0" && value == "ENDSEC"
        break
      end

      if inside && group_code == "9"
        var_name = value
        i += 2
        if i < lines.length - 1
          val_value = lines[i + 1]
          header[var_name] = val_value if val_value
          i += 2
        end
        next
      end

      i += 2
    end
    return {} if header.empty?

    acadver = header["$ACADVER"]
    savedby = header["$LASTSAVEDBY"]

    source = "autocad" if acadver&.start_with?("AC")
    source ||= "coreldraw" if savedby&.downcase&.include?("corel")
    source ||= "illustrator" if savedby&.downcase&.include?("illustrator")

    { source_program: source, acadver: acadver, last_saved_by: savedby }.compact
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
    preview_ext = version.extension.downcase == "dxf" ? "svg" : "png"
    preview_path = File.join(output_dir, "preview.#{preview_ext}")

    extension = version.extension.downcase
    meta = version.image_metadata
    if extension == "dxf"
      generate_preview_dxf(input_path, preview_path)
    elsif meta&.has_spots? && %w[tif tiff].include?(extension)
      generate_preview_utif(input_path, preview_path)
    elsif meta&.colorspace == "CMYK"
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

  def generate_preview_dxf(input, output)
    system("node", Rails.root.join("bin", "generate-dxf-preview.js").to_s, input, output) || raise("DXF preview failed")
  end

  def preview_enabled?(version)
    FileCategory.preview_enabled?(version.category)
  end
end
