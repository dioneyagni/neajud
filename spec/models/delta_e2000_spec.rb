require "rails_helper"

# Etapa 2.5b: test pairs from Sharma, Wu & Dalal (2005), "The CIEDE2000
# color-difference formula: implementation notes" — the published values to 4 places.
RSpec.describe DeltaE2000 do
  [
    [ [ 50.0, 2.6772, -79.7751 ], [ 50.0, 0.0, -82.7485 ], 2.0425 ],
    [ [ 50.0, 2.5, 0.0 ], [ 73.0, 25.0, -18.0 ], 27.1492 ],
    [ [ 50.0, 2.5, 0.0 ], [ 50.0, 0.0, -2.5 ], 4.3065 ],
    [ [ 60.2574, -34.0099, 36.2677 ], [ 60.4626, -34.1751, 39.4387 ], 1.2644 ],
    [ [ 22.7233, 20.0904, -46.6940 ], [ 23.0331, 14.9730, -42.5619 ], 2.0373 ],
    [ [ 90.8027, -2.0831, 1.4410 ], [ 91.1528, -1.6435, 0.0447 ], 1.4441 ],
    [ [ 2.0776, 0.0795, -1.1350 ], [ 0.9033, -0.0636, -0.5514 ], 0.9082 ]
  ].each do |lab1, lab2, esperado|
    it "gives #{esperado} for #{lab1} × #{lab2}" do
      expect(described_class.entre(lab1, lab2).round(4)).to eq(esperado)
      expect(described_class.entre(lab2, lab1).round(4)).to eq(esperado)
    end
  end

  it "is 0 for the same color" do
    expect(described_class.entre([ 54.3, 64.7, 55.3 ], [ 54.3, 64.7, 55.3 ])).to eq(0)
  end
end
