require "rails_helper"

RSpec.describe ArquivosHelper, type: :helper do
  describe "#format_time" do
    it "returns '0:00' for nil" do
      expect(helper.format_time(nil)).to eq("0:00")
    end

    it "formats seconds as hours:minutes" do
      expect(helper.format_time(3661)).to eq("1:01")
    end
  end

  describe "#format_cm" do
    it "returns nil when pixels is nil" do
      expect(helper.format_cm(nil, 300)).to be_nil
    end

    it "returns nil when dpi is nil" do
      expect(helper.format_cm(1000, nil)).to be_nil
    end

    it "returns nil when dpi is zero" do
      expect(helper.format_cm(1000, 0)).to be_nil
    end

    it "converts pixels to cm" do
      expect(helper.format_cm(300, 300)).to eq("2.5")
    end

    it "rounds to one decimal place" do
      expect(helper.format_cm(100, 300)).to eq("0.8")
    end
  end

  describe "#tamanhos_for_arte" do
    it "returns empty array for non-artes category" do
      arquivo = build(:arquivo, category: "corte")
      expect(helper.tamanhos_for_arte(arquivo)).to eq([])
    end

    it "returns direct tamanhos for artes without corte" do
      arquivo = create(:arquivo, category: "artes")
      create(:tamanho, arquivo: arquivo, nome: "P")
      create(:tamanho, arquivo: arquivo, nome: "M")

      result = helper.tamanhos_for_arte(arquivo)
      expect(result).to include({ nome: "P" }, { nome: "M" })
    end

    it "returns corte tamanhos for artes with corte_via_modelo" do
      corte = create(:arquivo, :corte)
      create(:tamanho, arquivo: corte, nome: "G")
      create(:tamanho, arquivo: corte, nome: "GG")
      arte = create(:arquivo, category: "artes")

      allow(arte).to receive(:corte_via_modelo).and_return(corte)

      result = helper.tamanhos_for_arte(arte)
      expect(result).to include({ nome: "G" }, { nome: "GG" })
    end
  end
end
