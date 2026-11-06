require "rails_helper"
require "open3"

# Painel 2/4a2 (decided 06/11/2026): bin/detect-tamanhos.js keeps each
# size's inner lines by layer color — the REFORÇO fixture has a red line
# and green holes (10 figures) inside each of its 5 sizes.
RSpec.describe "bin/detect-tamanhos.js" do
  it "returns each size's inner lines and closed figures by color" do
    dxf = Rails.root.join("spec/fixtures/files/REFORÇO - 35 AO 43.dxf").to_s
    saida, status = Open3.capture2("node", Rails.root.join("bin/detect-tamanhos.js").to_s, dxf, "REFORÇO - 35 AO 43")
    expect(status).to be_success
    primeiro = JSON.parse(saida)["tamanhos"].first
    expect(primeiro["linhas_por_cor"]).to eq("#FF0000" => { "mm" => 923.2, "figuras" => 10 }, "#00FF00" => { "mm" => 57.33, "figuras" => 10 })
    expect(primeiro["linhas_por_cor"].values.sum { |cor| cor["mm"] }).to be_within(0.01).of(primeiro["inner_lines_mm"])
  end
end
