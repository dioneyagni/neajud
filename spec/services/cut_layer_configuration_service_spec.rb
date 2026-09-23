require "rails_helper"

RSpec.describe CutLayerConfigurationService do
  let(:arquivo) { create(:arquivo, :corte) }
  let(:version) { create(:arquivo_version, arquivo: arquivo) }

  def annotations(hash)
    ActionController::Parameters.new(hash)
  end

  before do
    version.cut_layers.create!(layer_name: "Corte", color: "#FF0000", annotation: "cut", position: 0,
                               width_mm: 120.5, height_mm: 80.0, perimeter_mm: 400.0, area_mm2: 9000.0)
  end

  it "replaces layers with the submitted names and annotations, in order" do
    described_class.call(version, annotations(
      "0" => { layer_name: "Furo", color: "#00FF00", annotation: "hole" },
      "1" => { layer_name: "Corte", color: "#FF0000", annotation: "crease" }
    ))
    layers = version.cut_layers.reload.order(:position)
    expect(layers.map { |l| [ l.layer_name, l.color, l.annotation, l.position ] })
      .to eq([ [ "Furo", "#00FF00", "hole", 0 ], [ "Corte", "#FF0000", "crease", 1 ] ])
  end

  it "keeps measurements from the previous layer of the same color" do
    described_class.call(version, annotations("0" => { layer_name: "Renamed", color: "#FF0000", annotation: "cut" }))
    layer = version.cut_layers.reload.first
    expect([ layer.width_mm, layer.height_mm, layer.perimeter_mm, layer.area_mm2 ]).to eq([ 120.5, 80.0, 400.0, 9000.0 ])
  end

  it "leaves measurements empty for a color that had no previous layer" do
    described_class.call(version, annotations("0" => { layer_name: "New", color: "#0000FF", annotation: "cut" }))
    expect(version.cut_layers.reload.first.width_mm).to be_nil
  end

  it "defaults the annotation to cut when none is sent" do
    described_class.call(version, annotations("0" => { layer_name: "Corte", color: "#FF0000" }))
    expect(version.cut_layers.reload.first.annotation).to eq("cut")
  end

  it "re-runs DXF organization when it had failed" do
    arquivo.update!(organize_error: "stacked cuts")
    expect(DxfOrganizationService).to receive(:call).with(arquivo)
    described_class.call(version, annotations("0" => { layer_name: "Corte", color: "#FF0000", annotation: "hole" }))
  end

  it "does not re-run DXF organization when it had succeeded" do
    expect(DxfOrganizationService).not_to receive(:call)
    described_class.call(version, annotations("0" => { layer_name: "Corte", color: "#FF0000", annotation: "cut" }))
  end
end
