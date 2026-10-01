require "rails_helper"

# Etapa 1.1 (5/5): an arte's Referência + Nome and its computed full name.
RSpec.describe NomeDeArte do
  let(:tenis) { create(:modelo, abreviacao: "TNS") }
  let(:molde) { create(:molde, modelo: tenis, sufixo: "Base") }
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:corte) { create(:arquivo, :corte, organized: true, peca: lateral) }
  let(:tamanho) { create(:tamanho, arquivo: corte, nome: "29-30") }
  let(:dezenove) { create(:referencia, molde: molde, nome: "19") }

  def arte(nome: "Bluey Azul", referencia: dezenove, tamanho: self.tamanho, **attrs)
    create(:arquivo, category: "artes", molde: molde, referencia: referencia, nome: nome, tamanho: tamanho, **attrs)
  end

  describe "#nome_completo" do
    it "joins code, referência, name, part and size, skipping empty pieces" do
      expect(arte(nome: "Bluey Azul").nome_completo).to eq("001-TNS_19_Bluey Azul_Lateral_29-30")
      expect(arte(nome: nil, referencia: nil, tamanho: nil, peca: lateral).nome_completo).to eq("001-TNS_Lateral")
    end

    it "drops accents and unsafe characters in a file name" do
      expect(arte(nome: "Coração/Azul").nome_completo(para_arquivo: true)).to eq("001-TNS_19_Coracao-Azul_Lateral_29-30")
    end

    it "is nil for a corte or an arte without molde" do
      expect(corte.nome_completo).to be_nil
      expect(create(:arquivo, category: "artes").nome_completo).to be_nil
    end
  end

  describe "#artes_com_mesmo_nome" do
    it "finds the same molde, referência, size and name ignoring case and accents" do
      primeira = arte(nome: "Coração")
      segunda = arte(nome: "CORACAO")
      expect(segunda.artes_com_mesmo_nome).to eq([ primeira ])
    end

    # Until Etapa 1.2 each size is its own arte: 29-30 and 31-32 aren't repeats.
    it "doesn't mix other sizes, referências or trashed artes" do
      arte(nome: "Coração", tamanho: create(:tamanho, arquivo: corte, nome: "31-32"))
      arte(nome: "Coração", referencia: create(:referencia, molde: molde, nome: "20"))
      arte(nome: "Coração").excluir!(changed_by: "10.0.0.1")
      expect(arte(nome: "Coração").artes_com_mesmo_nome).to be_empty
    end

    it "needs a name and a size to compare" do
      arte(nome: nil)
      expect(arte(nome: nil).artes_com_mesmo_nome).to be_empty
    end
  end

  describe "#ajustar_referencia_e_nome!" do
    it "fills blanks from the file name, creating the referência in the molde" do
      nova = create(:arquivo, category: "artes", molde: molde, filename: "21-GATO PRETO-LATERAL")
      lateral
      nova.ajustar_referencia_e_nome!
      expect([ nova.reload.referencia.nome, nova.nome, nova.referencia.molde ]).to eq([ "21", "GATO PRETO", molde ])
    end

    it "keeps what was typed by hand" do
      escolhida = arte(nome: "Meu nome", filename: "21-OUTRO")
      escolhida.ajustar_referencia_e_nome!
      expect([ escolhida.reload.referencia, escolhida.nome ]).to eq([ dezenove, "Meu nome" ])
    end

    it "drops another molde's referência and reads the file name again" do
      movida = arte(filename: "22-NOVO")
      movida.update_columns(molde_id: create(:molde).id)
      movida.reload.ajustar_referencia_e_nome!
      expect(movida.reload.referencia.nome).to eq("22")
      expect(movida.referencia.molde).to eq(movida.molde)
    end
  end

  it "refuses a referência of another molde" do
    outra = create(:referencia, molde: create(:molde), nome: "99")
    errada = build(:arquivo, category: "artes", molde: molde, referencia: outra)
    expect(errada).not_to be_valid
    expect(errada.errors[:referencia].first).to include("\"99\" belongs to another molde")
  end

  it "suggests the names already used in the referência, once each" do
    arte(nome: "Bluey Azul")
    arte(nome: "bluey azul", tamanho: create(:tamanho, arquivo: corte, nome: "31-32"))
    arte(nome: "Gato", tamanho: create(:tamanho, arquivo: corte, nome: "33-34"))
    expect(arte(nome: nil).sugestoes_de_nome).to eq([ "Bluey Azul", "Gato" ])
  end
end
