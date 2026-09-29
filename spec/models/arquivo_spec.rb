require "rails_helper"

RSpec.describe Arquivo, type: :model do
  subject(:arquivo) { build(:arquivo) }

  describe "validations" do
    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:extension) }
    it { should validate_presence_of(:mime_type) }
  end

  describe "associations" do
    it { should have_many(:arquivo_time_logs).dependent(:destroy) }
    it { should have_many(:arquivo_versions) }
    it { should belong_to(:client).optional }
    it { should belong_to(:molde).optional }
    it { should belong_to(:peca).optional }
    it { should belong_to(:modelo).optional }
    it { should belong_to(:tamanho).optional }
  end

  describe "statuses" do
    it "defines status enum with correct values" do
      expect(Arquivo.statuses).to eq({
        "pending" => "pending",
        "processing" => "processing",
        "processed" => "processed",
        "failed" => "failed",
        "invalid_colorspace" => "invalid_colorspace",
        "unsupported_format" => "unsupported_format"
      })
    end
  end

  describe "callbacks" do
    it "generates uuid before create" do
      arquivo.save!
      expect(arquivo.uuid).to be_present
      expect(arquivo.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "SUPPORTED_EXTENSIONS" do
    it "includes all Artes formats" do
      artes = %w[tif tiff psd ai eps cdr pdf]
      expect(Arquivo::SUPPORTED_EXTENSIONS).to include(*artes)
    end

    it "includes all Corte formats" do
      corte = %w[dxf svg dwg cad]
      expect(Arquivo::SUPPORTED_EXTENSIONS).to include(*corte)
    end

    it "does not include removed formats" do
      expect(Arquivo::SUPPORTED_EXTENSIONS).not_to include("jpg", "jpeg")
    end
  end

  describe "peca_modelo_uniqueness_for_organized_corte" do
    let(:modelo) { create(:modelo) }
    let(:peca) { create(:peca) }
    let(:molde) { create(:molde) }

    before do
      create(:molde_peca, molde: molde, peca: peca)
    end

    it "allows first organized corte with a peca for a modelo" do
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      corte1.modelos << modelo
      expect(corte1).to be_valid
    end

    it "rejects second organized corte with same peca for same modelo" do
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      corte1.modelos << modelo

      corte2 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      corte2.modelos << modelo
      expect(corte2).not_to be_valid
      expect(corte2.errors[:peca_id]).to include(a_string_matching(/já está em uso/))
    end

    it "allows same peca for different modelos" do
      modelo2 = create(:modelo)
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      corte1.modelos << modelo

      corte2 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      corte2.modelos << modelo2
      expect(corte2).to be_valid
    end

    it "does not block different pecas for same modelo" do
      peca2 = create(:peca)
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      corte1.modelos << modelo

      corte2 = create(:arquivo, :corte, organized: true, peca: peca2, molde: molde)
      corte2.modelos << modelo
      expect(corte2).to be_valid
    end

    it "ignores validation when not corte category" do
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      corte1.modelos << modelo

      arte = create(:arquivo, category: "artes", organized: true, peca: peca)
      arte.modelos << modelo
      expect(arte).to be_valid
    end

    it "does not block when arquivo has no linked modelos" do
      # Intentional, not a gap: the constraint is scoped per modelo (peca X
      # can't be organized-corte twice for the SAME modelo). An arquivo with
      # no modelo linked yet has no modelo to conflict on — the check runs
      # again once a modelo is actually attached, see
      # "POST /arquivos/:id/add_modelo" in spec/requests/arquivos_spec.rb.
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      corte1.modelos << modelo

      corte2 = build(:arquivo, :corte, organized: true, peca: peca, molde: molde)
      expect(corte2).to be_valid
    end

    context "with peca_occupied_for_modelos? called with an explicit peca_id" do
      it "checks the given peca_id instead of self.peca_id" do
        peca2 = create(:peca)
        corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
        corte1.modelos << modelo

        corte2 = create(:arquivo, :corte, peca: peca2, molde: molde)
        corte2.modelos << modelo

        expect(corte2.peca_occupied_for_modelos?(peca_id: peca.id)).to be true
        expect(corte2.peca_occupied_for_modelos?(peca_id: peca2.id)).to be false
      end

      it "returns false for a non-corte arquivo regardless of peca_id" do
        corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
        corte1.modelos << modelo

        arte = create(:arquivo, category: "artes")
        arte.modelos << modelo

        expect(arte.peca_occupied_for_modelos?(peca_id: peca.id)).to be false
      end
    end

    context "with conflicting_corte class method" do
      it "returns the conflicting arquivo" do
        corte1 = create(:arquivo, :corte, organized: true, peca: peca, molde: molde)
        corte1.modelos << modelo

        result = described_class.conflicting_corte(peca_id: peca.id, modelo: modelo)
        expect(result).to eq(corte1)
      end

      it "returns nil when no conflict exists" do
        result = described_class.conflicting_corte(peca_id: peca.id, modelo: modelo)
        expect(result).to be_nil
      end

      it "returns nil when peca_id is blank" do
        result = described_class.conflicting_corte(peca_id: nil, modelo: modelo)
        expect(result).to be_nil
      end

      it "returns nil when modelo is nil" do
        result = described_class.conflicting_corte(peca_id: peca.id, modelo: nil)
        expect(result).to be_nil
      end
    end
  end

  # Regression: arquivos.tamanho_id has a real DB foreign key (db/schema.rb),
  # so destroying a corte whose Tamanho is still referenced by an arte's
  # tamanho_id used to raise an unhandled SQLite3::ConstraintException (an
  # unlogged 500) instead of a normal validation failure.
  describe "destroy guard for arquivos linked via tamanho_id" do
    it "blocks destroy and adds a base error when an arte still references a tamanho" do
      corte = create(:arquivo, :corte)
      tamanho = create(:tamanho, arquivo: corte)
      arte = create(:arquivo, tamanho: tamanho)

      expect(corte.destroy).to be false
      expect(corte.errors[:base].first).to include("1 arquivo", arte.filename)
      expect(Arquivo.exists?(corte.id)).to be true
      expect(Arquivo.exists?(arte.id)).to be true
    end

    it "does not raise (no unhandled exception reaches the caller)" do
      corte = create(:arquivo, :corte)
      tamanho = create(:tamanho, arquivo: corte)
      create(:arquivo, tamanho: tamanho)

      expect { corte.destroy }.not_to raise_error
    end

    it "allows destroy when no other arquivo references its tamanhos" do
      corte = create(:arquivo, :corte)
      create(:tamanho, arquivo: corte)

      expect(corte.destroy).to be_truthy
      expect(Arquivo.exists?(corte.id)).to be false
    end

    it "allows destroy once the linking arte no longer references the tamanho" do
      corte = create(:arquivo, :corte)
      tamanho = create(:tamanho, arquivo: corte)
      arte = create(:arquivo, tamanho: tamanho)
      arte.update!(tamanho: nil)

      expect(corte.destroy).to be_truthy
    end
  end

  describe "#resolved_peca" do
    let(:peca_do_corte) { create(:peca, nome: "Lateral") }
    let(:corte) { create(:arquivo, :corte, peca: peca_do_corte) }

    it "is the peça of the corte its tamanho belongs to" do
      arte = create(:arquivo, tamanho: create(:tamanho, arquivo: corte))
      expect(arte.resolved_peca).to eq(peca_do_corte)
    end

    it "prefers the corte's peça over the arte's own peca_id" do
      arte = create(:arquivo, tamanho: create(:tamanho, arquivo: corte), peca: create(:peca, nome: "Outra"))
      expect(arte.resolved_peca).to eq(peca_do_corte)
    end

    it "falls back to the arte's own peca_id without tamanho" do
      lingua = create(:peca, nome: "Língua")
      expect(create(:arquivo, peca: lingua).resolved_peca).to eq(lingua)
    end

    it "is nil when neither is set" do
      expect(create(:arquivo).resolved_peca).to be_nil
    end
  end

  # Regression (28/09/2026): several modelos share a molde, each with its own
  # cortes; the molde's first corte was taken as every modelo's corte.
  describe ".cortes_do_modelo / #corte_via_modelo" do
    let(:molde) { create(:molde) }
    let(:lateral) { create(:peca, nome: "Lateral") }
    let(:lingua) { create(:peca, nome: "Língua") }
    let(:outro_modelo) { create(:modelo, molde: molde, nome: "21-24") }
    let(:modelo) { create(:modelo, molde: molde, nome: "28-29") }

    def corte(peca, *modelos)
      create(:arquivo, :corte, organized: true, molde: molde, peca: peca).tap { |c| modelos.each { |m| c.modelos << m } }
    end

    it "takes the cortes linked to the modelo, not the whole molde's" do
      corte(lateral, outro_modelo)
      meu = corte(lateral, modelo)
      expect(described_class.cortes_do_modelo(modelo)).to contain_exactly(meu)
    end

    it "falls back to the molde's cortes when none is linked to the modelo" do
      solto = create(:arquivo, :corte, organized: true, molde: molde)
      expect(described_class.cortes_do_modelo(modelo)).to contain_exactly(solto)
    end

    it "picks the corte of the arte's own peça, else the first" do
      c_lingua = corte(lingua, modelo)
      c_lateral = corte(lateral, modelo)
      expect(create(:arquivo, modelo: modelo, peca: lateral).corte_via_modelo).to eq(c_lateral)
      expect(create(:arquivo, modelo: modelo).corte_via_modelo).to eq(c_lingua)
    end

    # Guessing lateral vs língua would assign a wrong size; the user picks it.
    it "#corte_inequivoco_via_modelo is nil when several cortes and no peça" do
      corte(lingua, modelo)
      corte(lateral, modelo)
      expect(create(:arquivo, modelo: modelo).corte_inequivoco_via_modelo).to be_nil
    end
  end
end
