require "rails_helper"
require_relative "../support/fake_medida_de_cor"

# Etapa 2.5b (decided 12/10/2026): a cor lisa is measured per version and
# named by the system at its first measure — "Laranja 1" — never renamed.
RSpec.describe MedirCorJob do
  let(:medidor) { FakeMedidaDeCor.new("#EF4123") }

  around do |exemplo|
    anterior = described_class.medidor
    described_class.medidor = medidor
    exemplo.run
  ensure
    described_class.medidor = anterior
  end

  def cor_lisa(numero = 1)
    create(:arquivo, category: "artes", arte: Arte.novo_do_tipo("cor_lisa")).tap do |arquivo|
      arquivo.update!(approved_version: create(:arquivo_version, arquivo: arquivo, version_number: numero, status: :processed))
    end
  end

  it "measures the version and names the arte by its family, numbered per family" do
    primeira = cor_lisa
    segunda = cor_lisa
    azul = cor_lisa
    [ primeira, segunda ].each { |arquivo| described_class.perform_now(arquivo.approved_version.id) }
    medidor.passar_a_medir("#0071BB")
    described_class.perform_now(azul.approved_version.id)
    expect([ primeira, segunda, azul ].map { |a| a.arte.reload.codigo }).to eq([ "Laranja 1", "Laranja 2", "Azul 1" ])
    expect(primeira.approved_version.reload).to have_attributes(cor_hex: "#EF4123", lab: MedidaDeCor.lab_do_hex("#EF4123"))
  end

  it "measures a new version again, keeping the name — even when the tone moves to another family" do
    arquivo = cor_lisa
    described_class.perform_now(arquivo.approved_version.id)
    medidor.passar_a_medir("#ED1C24")
    nova = create(:arquivo_version, arquivo: arquivo, version_number: 2, status: :pending)
    arquivo.update!(approved_version: nova)
    nova.update!(status: :processed) # queues the measure itself
    expect(arquivo.arte.reload.codigo).to eq("Laranja 1")
    expect(arquivo.arte.cor_medida.cor_hex).to eq("#ED1C24")
  end

  it "leaves every other kind alone" do
    arquivo = create(:arquivo, category: "artes", arte: Arte.novo_do_tipo("dtf"))
    arquivo.update!(approved_version: create(:arquivo_version, arquivo: arquivo, version_number: 1, status: :processed))
    described_class.perform_now(arquivo.approved_version.id)
    expect(medidor.medidos).to be_empty
  end

  it "measures an arte that becomes a cor lisa on its page" do
    arquivo = create(:arquivo, category: "artes")
    arquivo.update!(approved_version: create(:arquivo_version, arquivo: arquivo, version_number: 1, status: :processed))
    arquivo.arte.trocar_tipo!("cor_lisa")
    expect(arquivo.arte.reload.codigo).to eq("Laranja 1")
  end
end
