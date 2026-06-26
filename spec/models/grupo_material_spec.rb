require "rails_helper"

RSpec.describe GrupoMaterial, type: :model do
  describe "validations" do
    subject { GrupoMaterial.new(nome: "Test Group #{Time.now.to_i}") }
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
end
