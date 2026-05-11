require "shellwords"

class FileValidator
  EXTENSION_TO_FORMAT = {
    "tif" => "TIFF", "tiff" => "TIFF",
    "psd" => "PSD",
    "jpg" => "JPEG", "jpeg" => "JPEG",
    "ai" => "PDF",
    "eps" => "EPT",
    "cdr" => "CDR"
  }.freeze

  def initialize(file_path)
    @file_path = file_path
  end

  def real_format
    @real_format ||= begin
      result = `identify -ping -format '%m\\n' #{Shellwords.escape(@file_path)} 2>/dev/null`
      fmt = result.lines.first&.strip
      fmt.present? ? fmt : nil
    end
  end

  def colorspace
    @colorspace ||= begin
      result = `identify -ping -format '%[colorspace]\\n' #{Shellwords.escape(@file_path)} 2>/dev/null`
      cs = result.lines.first&.strip
      cs.present? ? cs : nil
    end
  end

  def valid_extension?(extension)
    expected = EXTENSION_TO_FORMAT[extension.downcase]
    return false unless expected
    return true if real_format == expected

    if extension.downcase == "ai" && real_format == "PDF"
      return true
    end

    false
  end

  def valid_mime_type?(declared_mime)
    return true if declared_mime.blank?
    real_mime = format_to_mime(real_format)
    return false if real_mime.nil?
    declared_mime == real_mime
  end

  private

  def format_to_mime(format)
    {
      "TIFF" => "image/tiff",
      "PSD" => "image/vnd.adobe.photoshop",
      "JPEG" => "image/jpeg",
      "PDF" => "application/pdf",
      "EPT" => "application/postscript",
      "CDR" => "application/coreldraw"
    }[format]
  end
end
