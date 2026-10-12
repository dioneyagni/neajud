require "rails_helper"
require_relative "../support/fake_mold_matcher"

RSpec.describe TamanhoAutoAssignJob do
  let(:tamanho) { create(:tamanho, arquivo: create(:arquivo, :corte)) }
  let(:arte) { create(:arquivo, buscando_tamanho_desde: Time.current) }

  after { described_class.matcher = MoldMatchService }

  it "assigns the matched tamanho, clears the mark and refreshes the arte page" do
    described_class.matcher = FakeMoldMatcher.new(tamanho)
    expect(CanaisAoVivo).to receive(:recarregar).with(arte)
    described_class.perform_now(arte.id)
    expect(arte.reload).to have_attributes(tamanho_id: tamanho.id, buscando_tamanho_desde: nil)
  end

  # Found or not, the page must never stay on "Procurando tamanho…".
  it "clears the mark and refreshes also when nothing matches or the search fails" do
    described_class.matcher = FakeMoldMatcher.new(nil)
    described_class.perform_now(arte.id)
    expect(arte.reload.buscando_tamanho_desde).to be_nil

    arte.update_column(:buscando_tamanho_desde, Time.current)
    described_class.matcher = Class.new { def self.call(_) = raise("identify crashed") }
    expect { described_class.perform_now(arte.id) }.to raise_error("identify crashed")
    expect(arte.reload.buscando_tamanho_desde).to be_nil
  end

  it "ignores an arquivo that no longer exists" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
