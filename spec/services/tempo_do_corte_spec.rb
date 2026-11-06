require "rails_helper"

# Painel 2/4a2 (decided 06/11/2026, A2–A6): the cutting machine's time —
# the cut line at its speed, a punch per hole, the setup per meter of
# fabric, the unloading per piece and each change of material.
RSpec.describe TempoDoCorte do
  let(:corte) { create(:arquivo, :corte) }
  let(:ritmo) { RitmoProducao.de("calcado", "corte") }
  # Contour 1000 mm + Cut 500 mm (no layer: cut) = 1500 mm; 10 holes; the
  # Ignore and Engraving lines are not cut.
  let(:tamanho) do
    create(:tamanho, arquivo: corte, nome: "37", perimeter_mm: 1000, total_line_mm: 2160,
                     linhas_por_cor: { "#FF0000" => { "mm" => 500, "figuras" => 0 }, "#00FF00" => { "mm" => 60, "figuras" => 10 },
                                       "#0000FF" => { "mm" => 300, "figuras" => 2 }, "#FF00FF" => { "mm" => 300, "figuras" => 0 } })
  end

  before do
    versao = create(:arquivo_version, arquivo: corte, approved: true, status: "processed")
    corte.update!(approved_version: versao)
    { "#00FF00" => "hole", "#0000FF" => "ignore", "#ff00ff" => "engraving" }.each_with_index do |(cor, tipo), i|
      CutLayer.create!(arquivo_version: versao, layer_name: "Layer #{i}", color: cor, annotation: tipo)
    end
  end

  def linha(material, pecas: 10, metros: 0.5, de: tamanho)
    LinhasDeProducao::Linha.new(tamanho: de, pecas: pecas, esperado: metros, materia_prima: material)
  end

  it "adds the machine, the setup per meter and the unloading per piece" do
    # 10 × (1500 / 100 + 10 × 2) = 350 s; 0,5 m × 5 min = 150 s; 10 ÷ 50/min = 12 s.
    tempo = described_class.call([ linha(:oxford) ], ritmo)
    expect([ tempo.segundos, tempo.ultimo_material, tempo.sem_medida ]).to eq([ 512.0, :oxford, [] ])
  end

  it "takes the dono's parameters over the defaults" do
    ritmo.assign_attributes(velocidade_mm_s: 150, pinca_s: 1, preparo_min: 2, recolhimento_pecas_min: 20)
    # 10 × (10 + 10) = 200; 0,5 × 120 = 60; 10 ÷ 20 × 60 = 30.
    expect(described_class.call([ linha(:oxford) ], ritmo).segundos).to eq(290.0)
  end

  it "counts a change for each other material, and from the one the machine ended on" do
    linhas = [ linha(:oxford), linha(:helanca) ]
    expect(described_class.call(linhas, ritmo).segundos).to eq(1024.0 + 600)
    # Helanca already on the machine goes first: one change, it ends on Oxford.
    expect(described_class.call(linhas, ritmo, anterior: :helanca).then { |t| [ t.segundos, t.ultimo_material ] }).to eq([ 1624.0, :oxford ])
    expect(described_class.call(linhas, ritmo, anterior: :tactel).segundos).to eq(1024.0 + 1200)
  end

  it "names a size with no measure instead of counting it" do
    sem = create(:tamanho, arquivo: corte, nome: "39", position: 2)
    tempo = described_class.call([ linha(:oxford, de: sem) ], ritmo)
    expect([ tempo.segundos, tempo.sem_medida ]).to eq([ 162.0, [ "39" ] ])
  end
end
