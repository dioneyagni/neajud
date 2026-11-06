require "rails_helper"
require_relative "../support/fake_detector_de_camadas"

# Painel 2/4a2 (decided 06/11/2026): the cortes detected before the lines
# by layer were kept get them, each size by its position — never recreated.
RSpec.describe MedirCamadasDoCorte do
  let(:corte) { create(:arquivo, :corte) }
  let!(:p35) { create(:tamanho, arquivo: corte, nome: "35", position: 1) }
  let!(:p37) { create(:tamanho, arquivo: corte, nome: "37", position: 2) }

  it "writes each size's lines by color, keeping the sizes" do
    detector = FakeDetectorDeCamadas.new("tamanhos" => [ { "position" => 1, "linhas_por_cor" => { "#FF0000" => { "mm" => 923.2, "figuras" => 10 } } },
                                                         { "position" => 2, "linhas_por_cor" => {} } ])
    resultado = described_class.call(corte, detector: detector)
    expect([ resultado.medidos, resultado.sem_deteccao ]).to eq([ 2, 0 ])
    expect([ p35.reload.linhas_por_cor, p37.reload.linhas_por_cor, corte.tamanhos.pluck(:id) ]).to eq([ { "#FF0000" => { "mm" => 923.2, "figuras" => 10 } }, {}, [ p35.id, p37.id ] ])
  end

  it "leaves the sizes it no longer finds, and everything when the detection fails" do
    detector = FakeDetectorDeCamadas.new("tamanhos" => [ { "position" => 1, "linhas_por_cor" => {} } ])
    expect(described_class.call(corte, detector: detector).then { |r| [ r.medidos, r.sem_deteccao ] }).to eq([ 1, 1 ])
    expect(described_class.call(corte, detector: FakeDetectorDeCamadas.new(nil)).sem_deteccao).to eq(2)
    expect(p37.reload.linhas_por_cor).to be_nil
  end
end
