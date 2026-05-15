class FileCategory
  CATEGORIES = {
    "artes" => {
      extensions: %w[tif tiff psd ai eps cdr pdf],
      preview: true,
      spot_detection: true,
      label: "Art",
      notes: {
        "pdf" => "PDF for print"
      }
    },
    "corte" => {
      extensions: %w[dxf svg dwg cad],
      preview: false,
      spot_detection: false,
      label: "Cut",
      notes: {
        "pdf" => "PDF with cut vectors"
      }
    }
  }.freeze

  def self.all
    CATEGORIES
  end

  def self.keys
    CATEGORIES.keys
  end

  def self.extensions
    @extensions ||= CATEGORIES.values.flat_map { |c| c[:extensions] }.uniq.freeze
  end

  def self.for_extension(ext)
    ext = ext.downcase
    CATEGORIES.each do |name, config|
      return name if config[:extensions].include?(ext)
    end
    nil
  end

  def self.preview_enabled?(category)
    config = CATEGORIES[category]
    config ? config[:preview] : true
  end

  def self.spot_detection_enabled?(category)
    config = CATEGORIES[category]
    config ? config[:spot_detection] : false
  end

  def self.notes(extension, category)
    CATEGORIES.dig(category, :notes, extension.downcase) || ""
  end

  EXTENSION_ICONS = {
    "tif" => "icons/extensions/image",
    "tiff" => "icons/extensions/image",
    "psd" => "icons/extensions/psd",
    "ai" => "icons/extensions/ai",
    "eps" => "icons/extensions/eps",
    "cdr" => "icons/extensions/cdr",
    "pdf" => "icons/extensions/pdf",
    "dxf" => "icons/extensions/dxf",
    "svg" => "icons/extensions/svg",
    "dwg" => "icons/extensions/dwg",
    "cad" => "icons/extensions/cad"
  }.freeze

  PROGRAM_ICONS = {
    "tif" => "icons/programs/photoshop",
    "tiff" => "icons/programs/photoshop",
    "psd" => "icons/programs/photoshop",
    "ai" => "icons/programs/illustrator",
    "eps" => "icons/programs/illustrator",
    "cdr" => "icons/programs/coreldraw",
    "pdf" => "icons/programs/illustrator",
    "dxf" => "icons/programs/autocad",
    "svg" => "icons/programs/illustrator",
    "dwg" => "icons/programs/autocad",
    "cad" => "icons/programs/autocad"
  }.freeze

  def self.extension_icon(ext)
    EXTENSION_ICONS[ext.downcase] || "icons/extensions/image"
  end

  def self.program_icon(ext, detected_program: nil)
    return "icons/programs/#{detected_program}" if detected_program
    PROGRAM_ICONS[ext.downcase] || "icons/programs/photoshop"
  end
end
