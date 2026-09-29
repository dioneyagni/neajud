require "rails_helper"
require_relative "../support/fake_organizador_dxf"

RSpec.describe PreparacaoTamanhosJob do
  let(:corte) { create(:arquivo, :corte, preparando_tamanhos_desde: Time.current) }
  let(:organizador) { FakeOrganizadorDxf.new }

  before { described_class.organizador = organizador }
  after { described_class.organizador = DxfOrganizationService }

  it "re-detects when asked, else only prepares each size's DXF and preview" do
    allow_any_instance_of(Arquivo).to receive(:broadcast_refresh)
    described_class.perform_now(corte.id, true)
    described_class.perform_now(corte.id, false)
    expect(organizador.chamadas).to eq([ [ :redetectar, corte.id ], [ :previews, corte.id ] ])
  end

  it "clears the mark and refreshes the corte page" do
    expect_any_instance_of(Arquivo).to receive(:broadcast_refresh)
    described_class.perform_now(corte.id, false)
    expect(corte.reload.preparando_tamanhos_desde).to be_nil
  end

  # Found or not, the page must never stay on "Preparando os tamanhos…".
  it "clears the mark even when preparing fails" do
    described_class.organizador = FakeOrganizadorDxf.new(falha: "node crashed")
    allow_any_instance_of(Arquivo).to receive(:broadcast_refresh)
    expect { described_class.perform_now(corte.id, true) }.to raise_error("node crashed")
    expect(corte.reload.preparando_tamanhos_desde).to be_nil
  end

  it "ignores an arquivo that no longer exists" do
    expect { described_class.perform_now(0, false) }.not_to raise_error
  end
end
