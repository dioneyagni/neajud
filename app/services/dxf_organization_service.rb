class DxfOrganizationService
  OVERLAP_ERROR = "file has 1 or more stacked cuts"

  def self.call(stamp)
    new(stamp).call
  end

  def initialize(stamp)
    @stamp = stamp
  end

  def call
    return unless @stamp.extension.downcase == "dxf"

    version = @stamp.approved_version
    return unless version

    input_path = version.original_path
    return unless File.exist?(input_path)

    detect_tamanhos(input_path)
  end

  private

  def detect_tamanhos(path)
    script = Rails.root.join("bin", "detect-tamanhos.js").to_s
    output = `node #{Shellwords.escape(script)} #{Shellwords.escape(path)} 2>/dev/null`.strip
    return if output.blank?

    result = JSON.parse(output)
    return unless result["tamanhos"].is_a?(Array) && result["tamanhos"].any?

    @stamp.tamanhos.destroy_all
    tamanho_records = result["tamanhos"].map do |t|
      @stamp.tamanhos.create!(
        nome: t["nome"],
        position: t["position"],
        width_mm: t["width_mm"],
        height_mm: t["height_mm"],
        area_mm2: t["area_mm2"]
      )
    end

    overlaps = result["overlaps"] || []
    if overlaps.any?
      hole_colors = cut_layer_hole_colors
      colors_to_remove = overlaps
        .flat_map { |o| [ o["color_a"], o["color_b"] ] }
        .uniq
        .select { |c| hole_colors.include?(c) }

      if colors_to_remove.any?
        remove_tamanhos_by_color(colors_to_remove, tamanho_records, result["tamanhos"])
      end

      unresolved = overlaps.reject { |o|
        colors_to_remove.include?(o["color_a"]) || colors_to_remove.include?(o["color_b"])
      }

      if unresolved.any?
        @stamp.update!(organize_error: OVERLAP_ERROR)
      else
        @stamp.update!(organize_error: nil)
      end
    else
      @stamp.update!(organize_error: nil)
    end
  rescue JSON::ParserError
    nil
  end

  def cut_layer_hole_colors
    version = @stamp.approved_version
    return [] unless version

    version.cut_layers.where(annotation: "hole").pluck(:color)
  end

  def remove_tamanhos_by_color(colors, records, raw_data)
    raw_data.each_with_index do |raw, idx|
      next unless colors.include?(raw["color"])

      records[idx]&.destroy!
    end
  end
end
