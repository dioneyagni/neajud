require "rails_helper"

# Etapa 2.5b (decided 12/10/2026): the family, by the fixed table, of the
# factory's own samples — the average color each file measured on 12/10/2026.
RSpec.describe FamiliasDeCor do
  {
    "#FFF33D" => "Amarelo", "#FFDC00" => "Amarelo", "#FEC10D" => "Amarelo",
    "#EF4123" => "Laranja", "#EF4722" => "Laranja", "#F16535" => "Laranja", "#F15D21" => "Laranja",
    "#0071BB" => "Azul", "#6D172F" => "Bordô",
    "#ED1C24" => "Vermelho", "#5C3A1E" => "Marrom", "#E8D9B5" => "Bege", "#E91E63" => "Rosa",
    "#2E7D32" => "Verde", "#6A1B9A" => "Roxo", "#FFFFFF" => "Branco", "#808080" => "Cinza", "#111111" => "Preto"
  }.each do |hex, familia|
    it "puts #{hex} in #{familia}" do
      expect(described_class.classificar(MedidaDeCor.lab_do_hex(hex))).to eq(familia)
    end
  end

  # A fluorescent ink has no CMYK: the "laranja-v01_Fluor" file is a pale
  # salmon on screen and in the measure. Known, not a bug of the table.
  it "reads the fluorescent orange's file as the pink it is in CMYK" do
    expect(described_class.classificar(MedidaDeCor.lab_do_hex("#EEA19D"))).to eq("Rosa")
  end

  it "covers every hue at every lightness (no hole in the bands)" do
    familias = (0..359).step(5).flat_map { |h| [ 10, 30, 55, 80, 95 ].flat_map { |l| [ 5, 20, 60 ].map { |c| [ l, c * Math.cos(h * Math::PI / 180), c * Math.sin(h * Math::PI / 180) ] } } }
    expect { familias.each { |lab| described_class.classificar(lab) } }.not_to raise_error
  end

  it "has the notice's limits" do
    expect([ described_class.limite(:praticamente_igual), described_class.limite(:parecida) ]).to eq([ 1.0, 3.0 ])
  end
end
