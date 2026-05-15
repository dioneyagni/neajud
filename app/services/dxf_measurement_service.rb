class DxfMeasurementService
  def self.call(version)
    new(version).call
  end

  def initialize(version)
    @version = version
    @input_path = version.original_path
  end

  def call
    return unless @version.extension.downcase == "dxf"
    return unless File.exist?(@input_path)
    return if @version.cut_layers.empty?

    measurements = run_measurement_script
    return if measurements.blank?

    apply_measurements(measurements)
  end

  private

  def run_measurement_script
    script = Rails.root.join("bin", "measure-dxf.js").to_s
    output = `node #{Shellwords.escape(script)} #{Shellwords.escape(@input_path)} 2>/dev/null`.strip
    return if output.blank?

    JSON.parse(output)
  rescue JSON::ParserError
    nil
  end

  def apply_measurements(measurements)
    measurements.each do |m|
      layer = @version.cut_layers.find_by(color: m["color"])
      next unless layer

      layer.update!(
        width_mm: m["width_mm"],
        height_mm: m["height_mm"],
        perimeter_mm: m["perimeter_mm"],
        area_mm2: m["area_mm2"]
      )
    end
  end
end
