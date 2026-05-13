class FileCategory
  CATEGORIES = {
    "artes" => {
      extensions: %w[tif tiff psd ai eps cdr pdf],
      preview: true,
      spot_detection: true,
      label: "Artes",
      notes: {
        "pdf" => "PDF para impressão"
      }
    },
    "corte" => {
      extensions: %w[dxf svg dwg cad],
      preview: false,
      spot_detection: false,
      label: "Corte",
      notes: {
        "pdf" => "PDF com vetores de corte"
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
end
