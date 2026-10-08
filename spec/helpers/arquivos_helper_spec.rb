require "rails_helper"

RSpec.describe ArquivosHelper, type: :helper do
  describe "#processamento_label" do
    it "names the queued states and humanizes the rest" do
      expect(%w[pending processing failed].map { |s| helper.processamento_label(s) }).to eq([ "Na fila", "Processando", "Failed" ])
    end
  end

  describe "#grade_proposta" do
    it "deduces the grade from the detected names while the corte has no type" do
      corte = create(:arquivo, :corte)
      create(:tamanho, arquivo: corte, position: 1, nome: "35")
      create(:tamanho, arquivo: corte, position: 2, nome: "37")
      expect(helper.grade_proposta(corte)).to eq(tipo: "impar", tamanhos: [ { nome: "34-35", numeros: %w[34 35] }, { nome: "36-37", numeros: %w[36 37] } ])
    end

    it "shows the corte's own grade once saved" do
      corte = create(:arquivo, :corte, tipo_grade: "pmg")
      create(:tamanho, arquivo: corte, nome: "P", numeros: %w[33 34])
      expect(helper.grade_proposta(corte)).to eq(tipo: "pmg", tamanhos: [ { nome: "P", numeros: %w[33 34] } ])
    end
  end

  describe "#tamanhos_no_campo" do
    it "shows the pair, the numbers of a labelled size, or the name without a type" do
      valores = [ [ "par", "29-30", %w[29 30] ], [ "pmg", "P", %w[33 34] ], [ "pmg", "M", [] ], [ nil, "Size 1", [] ] ]
      expect(valores.map { |tipo, nome, numeros| helper.tamanhos_no_campo(tipo: tipo, nome: nome, numeros: numeros) })
        .to eq([ "29-30", "33-34", "", "Size 1" ])
    end
  end

  # Etapa 2.2 (1/3): paper per printed piece, on the arte page.
  describe "#consumo_de_papel" do
    it "gives pieces per meter and the share of a meter, nil without the file's size" do
      version = create(:arquivo_version)
      ArquivoImageMetadata.create!(arquivo_version: version, width_px: 3000, height_px: 600, dpi: 300)
      arquivo = version.arquivo.tap { |a| a.update!(approved_version: version) }
      expect(helper.consumo_de_papel(arquivo, 1600)).to eq("118,1 por metro · 0,85% do metro")
      expect(helper.consumo_de_papel(create(:arquivo), 1600)).to be_nil
    end
  end

  describe "#pecas_por_metro_do_tamanho" do
    it "lists pieces per meter on each fitted width, nil while none was computed" do
      expect(helper.pecas_por_metro_do_tamanho(build(:tamanho, metros_por_peca: { "1600" => 0.01551, "1250" => 0.01971 })))
        .to eq("1,25 m: 50,7 peças/m · 1,60 m: 64,5 peças/m")
      expect(helper.pecas_por_metro_do_tamanho(build(:tamanho))).to be_nil
    end
  end
end
