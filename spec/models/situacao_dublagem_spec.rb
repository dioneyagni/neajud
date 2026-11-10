require "rails_helper"

# Rede editável 2/2b: a situação added from the rede's page gets its chave
# from the first name, and the name is unique.
RSpec.describe SituacaoDublagem do
  describe ".chave_para" do
    it "turns the name into lowercase words without accents joined by _" do
      expect(described_class.chave_para("Vai frequência")).to eq("vai_frequencia")
      expect(described_class.chave_para("  Tecido  Úmido! ")).to eq("tecido_umido")
    end

    it "adds _2, _3… when the chave is taken, and has one for a name with no letters" do
      described_class.create!(chave: "tecido_umido", nome: "Outro nome")
      described_class.create!(chave: "tecido_umido_2", nome: "Mais um")
      expect(described_class.chave_para("Tecido úmido")).to eq("tecido_umido_3")
      expect(described_class.chave_para("!!!")).to eq("situacao")
    end
  end

  it "fills the chave on create and keeps it when renamed" do
    situacao = described_class.create!(nome: " Tecido   úmido ")
    expect([ situacao.chave, situacao.nome ]).to eq([ "tecido_umido", "Tecido úmido" ])
    situacao.update!(nome: "Tecido encharcado")
    expect(situacao.reload.chave).to eq("tecido_umido")
  end

  it "refuses a name already taken, whatever the case, saying which" do
    described_class.create!(nome: "Tecido molha")
    repetida = described_class.new(nome: "TECIDO MOLHA")
    expect(repetida).not_to be_valid
    expect(repetida.errors.full_messages).to include("Nome TECIDO MOLHA já é uma situação da rede")
  end
end
