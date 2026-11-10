require "rails_helper"

# Rede editável 2/2a: the micras as typed on the ligação's page.
RSpec.describe LiganteDaLigacao do
  it "reads typed micras: blank any, a list, a minimum; nil for anything else" do
    leituras = [ "", "25, 35", "25 ou 35", "35 ou mais", "35+", "abc", "0", "25,", "-5" ].map { |texto| described_class.micras_digitadas(texto) }

    expect(leituras).to eq([ { micras: nil, micras_minimo: nil }, { micras: [ 25, 35 ], micras_minimo: nil }, { micras: [ 25, 35 ], micras_minimo: nil },
                             { micras: nil, micras_minimo: 35 }, { micras: nil, micras_minimo: 35 }, nil, nil, nil, nil ])
  end

  it "writes them back for the form, or what was typed in a refused save" do
    expect([ described_class.new(micras: [ 25, 35 ]), described_class.new(micras_minimo: 35), described_class.new ].map(&:micras_no_campo)).to eq([ "25, 35", "35 ou mais", "" ])
    expect(described_class.new(micras: [ 25 ]).tap { |ligante| ligante.texto_das_micras = "25 e 3" }.micras_no_campo).to eq("25 e 3")
  end
end
