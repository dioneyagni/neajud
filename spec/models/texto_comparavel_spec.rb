require "rails_helper"

RSpec.describe TextoComparavel do
  it "compares ignoring case, accents, ç and extra spaces" do
    expect(described_class.chave("  Língua  Cabeça ")).to eq("lingua cabeca")
    expect(described_class.iguais?("Bluey Azul", "BLUEY  AZUL")).to be true
    expect(described_class.iguais?("Bluey", "Bluey Azul")).to be false
    expect(described_class.chave(nil)).to eq("")
  end
end
