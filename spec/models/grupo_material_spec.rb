require "rails_helper"

RSpec.describe GrupoMaterial, type: :model do
  describe "validations" do
    # The matcher saves without validations, so the uuid (normally set by
    # GeraUuid before validation) must already be there.
    subject { GrupoMaterial.new(nome: "Test Group #{Time.now.to_i}", uuid: SecureRandom.uuid) }
    it { should validate_presence_of(:nome) }
    it { should validate_uniqueness_of(:nome).case_insensitive }
  end

  describe "associations" do
    it { should have_many(:materia_primas).dependent(:restrict_with_error) }
  end

  describe ".search" do
    it "returns groups matching the query" do
      GrupoMaterial.where(nome: "Test Search Group").destroy_all
      group = GrupoMaterial.create!(nome: "Test Search Group")
      expect(GrupoMaterial.search("Test Search Group")).to include(group)
    end

    it "returns all when query is blank" do
      expect(GrupoMaterial.search("")).to eq(GrupoMaterial.all)
    end
  end

  # Dublagem 1/5 (decided 27/10/2026): the group as a family.
  describe "as a family" do
    let(:espuma) { GrupoMaterial.create!(nome: "Espuma") }

    it "starts as a superfície that prints, asking a required gramatura (today's behavior)" do
      expect([ espuma.superficie, espuma.base, espuma.estampavel, espuma.atributos ]).to eq([ true, false, "sim", { "gramatura" => true } ])
    end

    it "sets the attributes asked, a required one asked too" do
      espuma.definir_atributos(pede: %w[fornecedor], obrigatorios: %w[densidade espessura_mm])
      expect(espuma.atributos).to eq("densidade" => true, "espessura_mm" => true, "fornecedor" => false)
      expect([ espuma.pede?("fornecedor"), espuma.exige?("fornecedor"), espuma.exige?(:densidade), espuma.pede?("gramatura") ]).to eq([ true, false, true, false ])
    end

    it "refuses an unknown attribute, an unknown printing option and ressalvas without their text" do
      espuma.atributos = { "cheiro" => true }
      espuma.estampavel = "talvez"
      expect(espuma).not_to be_valid
      expect(espuma.errors[:atributos].first).to include('["cheiro"] are not material attributes')
      expect(espuma.errors[:estampavel].first).to include("talvez is not a printing option")
      espuma.assign_attributes(atributos: {}, estampavel: "ressalvas")
      espuma.validate
      expect(espuma.errors.full_messages).to include("Ressalva diz qual é a ressalva (o aviso que o pedido mostra)")
    end

    it ".estampaveis leaves out the groups that don't print" do
      tnt = GrupoMaterial.create!(nome: "TNT", estampavel: "ressalvas", ressalva: "a cor fica mais clara")
      espuma.update!(estampavel: "nao")
      expect(GrupoMaterial.estampaveis.where(id: [ tnt.id, espuma.id ])).to eq([ tnt ])
    end
  end
end
