require "rails_helper"

RSpec.describe Tamanho, type: :model do
  describe "validations" do
    it { should validate_presence_of(:nome) }
  end

  describe "associations" do
    it { should belong_to(:arquivo) }
  end

  # Painel 2/4a2 (decided 06/11/2026): what the cutting machine goes through.
  describe "#corte_da_maquina" do
    let(:linhas) { { "#FF0000" => { "mm" => 500, "figuras" => 1 }, "#00ff00" => { "mm" => 60, "figuras" => 10 }, "#0000FF" => { "mm" => 300, "figuras" => 2 } } }

    it "cuts the contour and the Cut layers (and colors with no layer), punches the Hole ones, skips the rest" do
      corte = Tamanho.new(perimeter_mm: 1000, linhas_por_cor: linhas).corte_da_maquina("#00FF00" => "hole", "#0000FF" => "engraving")
      expect(corte.to_h).to eq(linha_mm: 1500.0, furos: 10, por_camada: true)
    end

    it "takes the whole line before the layers were measured, and nil with no measure" do
      expect(Tamanho.new(perimeter_mm: 1000, total_line_mm: 1860).corte_da_maquina({}).to_h).to eq(linha_mm: 1860.0, furos: 0, por_camada: false)
      expect(Tamanho.new.corte_da_maquina({})).to be_nil
      expect(Tamanho.new(linhas_por_cor: {}).corte_da_maquina({})).to be_nil
    end
  end

  describe "default scope" do
    it "orders by position" do
      arquivo = create(:arquivo)
      second = Tamanho.create!(nome: "G", position: 2, arquivo: arquivo)
      first = Tamanho.create!(nome: "P", position: 1, arquivo: arquivo)
      expect(Tamanho.where(arquivo: arquivo).to_a).to eq([ first, second ])
    end
  end

  describe "#atende_rotulo? (Etapa 1.2, 2/3)" do
    it "serves the numbers it covers, or its own label" do
      par = build(:tamanho, nome: "29-30", numeros: %w[29 30])
      pmg = build(:tamanho, nome: "P", numeros: %w[33 34])
      expect(%w[30 29-30 31].map { |r| par.atende_rotulo?(r) }).to eq([ true, true, false ])
      expect(%w[p 33 M].map { |r| pmg.atende_rotulo?(r) }).to eq([ true, true, false ])
    end

    it "matches a legacy size without numbers only by name" do
      expect(build(:tamanho, nome: "30", numeros: []).atende_rotulo?("30")).to be true
    end
  end

  # Etapa 2.2 (1/3): one fit per roll width.
  it "gives the meters per piece of a width, nil while not computed" do
    tamanho = build(:tamanho, metros_por_peca: { "1400" => 0.0183 })
    expect([ tamanho.metros_por_peca_em(1400), tamanho.metros_por_peca_em(1600) ]).to eq([ 0.0183, nil ])
  end
end
