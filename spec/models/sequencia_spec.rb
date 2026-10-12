require "rails_helper"

# Etapa 2.5a: numbers per empresa (instance), never reused.
RSpec.describe Sequencia do
  it "starts at 1 and counts each sequence apart" do
    expect([ described_class.proximo!("dtf"), described_class.proximo!("dtf"), described_class.proximo!("corrida") ]).to eq([ 1, 2, 1 ])
  end

  it "never gives back a number, even when its arte goes" do
    described_class.proximo!("dtf")
    Arte.where(numero: 1).delete_all
    expect(described_class.proximo!("dtf")).to eq(2)
  end
end
