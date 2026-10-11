require "rails_helper"

# Etapa 2.8 (3a, decided 10/10/2026): what a cliente final sees by kind — the
# empresa's default grid, then each client's exceptions.
RSpec.describe TiposParaCliente do
  let(:empresa) { Empresa.new(visibilidade_cliente: { "cortes" => true, "estoque" => false }) }

  describe ".abertos_para" do
    it "opens pedidos, moldes and estoque by default" do
      expect(described_class.abertos_para(build(:client), empresa: nil)).to eq(%w[pedidos moldes estoque])
    end

    it "reads the empresa's grid, then the client's exceptions over it" do
      client = build(:client, visibilidade: { "cortes" => false, "valores" => true })
      expect(described_class.abertos_para(build(:client), empresa: empresa)).to eq(%w[pedidos moldes cortes])
      expect(described_class.abertos_para(client, empresa: empresa)).to eq(%w[pedidos moldes valores])
    end
  end

  it ".padrao_da_empresa fills the kinds the empresa never set" do
    expect(described_class.padrao_da_empresa(empresa)).to include("cortes" => true, "estoque" => false, "pedidos" => true, "valores" => false)
  end

  it ".erros names an unknown kind and a value that isn't true/false" do
    expect(described_class.erros({ "custos" => true, "cortes" => "sim", "pedidos" => false })).to eq([
      "unknown kind \"custos\"; expected one of pedidos, moldes, estoque, original, cortes, valores",
      "invalid value \"sim\" for cortes; expected true or false"
    ])
  end

  it ".ler turns form values into the stored shape, dropping the kinds left on the default" do
    expect(described_class.ler({ "cortes" => "1", "valores" => "0", "pedidos" => "padrao" })).to eq({ "cortes" => true, "valores" => false })
  end

  it "is validated on the empresa and on the client" do
    expect(build(:client, visibilidade: { "custos" => true })).not_to be_valid
    expect(Empresa.new(nome: "E", visibilidade_cliente: { "cortes" => "x" }).tap(&:valid?).errors[:visibilidade_cliente]).to be_present
  end
end
