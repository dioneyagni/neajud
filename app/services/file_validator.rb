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
      result = `identify -format '%m' '#{@file_path}' 2>&1`
      result.strip unless result.include?("error") || result.include?("Warning")
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