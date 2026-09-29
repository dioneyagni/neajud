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

  # Etapa 0.6: re-detecting runs in the queue, not in the request.
  describe "re-running DXF organization" do
    around do |example|
      anterior = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = anterior
    end

    it "queues it (re-detecting) when it had failed" do
      arquivo.update!(organize_error: "stacked cuts")
      expect {
        described_class.call(version, annotations("0" => { layer_name: "Corte", color: "#FF0000", annotation: "hole" }))
      }.to have_enqueued_job(PreparacaoTamanhosJob).with(arquivo.id, true)
      expect(arquivo.reload.preparando_tamanhos?).to be true
    end

    it "doesn't when it had succeeded" do
      expect {
        described_class.call(version, annotations("0" => { layer_name: "Corte", color: "#FF0000", annotation: "cut" }))
      }.not_to have_enqueued_job(PreparacaoTamanhosJob)
    end
  end
end
