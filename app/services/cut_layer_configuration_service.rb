# Replaces a version's cut layers with the user-edited list from the Layer
# Configuration form. The form only sends name/color/annotation, so each
# layer's measurements are carried over from the previous layer of the same
# color. If DXF organization had failed (e.g. stacked cuts), it is re-run:
# marking a layer as "hole" can resolve the overlap.
#
# Usage: CutLayerConfigurationService.call(version, params[:layer_annotations])
class CutLayerConfigurationService
  MEASUREMENTS = %i[width_mm height_mm perimeter_mm area_mm2].freeze

  def self.call(version, annotations)
    new(version, annotations).call
  end

  def initialize(version, annotations)
    @version = version
    @annotations = annotations
  end

  def call
    previous_by_color = @version.cut_layers.index_by(&:color)
    @version.cut_layers.destroy_all
    permitted_layers.each_with_index do |layer, position|
      create_layer(layer, position, previous_by_color[layer["color"]])
    end
    reorganize_failed_dxf
  end

  private

  def permitted_layers
    @annotations.values.map { |v|
      v.is_a?(ActionController::Parameters) ? v.permit(:layer_name, :color, :annotation) : v.to_unsafe_h
    }
  end

  def create_layer(layer, position, previous)
    @version.cut_layers.create!(
      layer_name: layer["layer_name"],
      color: layer["color"],
      annotation: layer["annotation"] || "cut",
      position: position,
      **MEASUREMENTS.index_with { |m| previous&.public_send(m) }
    )
  end

  def reorganize_failed_dxf
    arquivo = @version.arquivo
    return unless arquivo.extension.downcase == "dxf" && arquivo.organize_error.present?

    DxfOrganizationService.call(arquivo)
  end
end
