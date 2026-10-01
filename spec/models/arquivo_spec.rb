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
    it { should belong_to(:modelo).optional }
    it { should belong_to(:peca).optional }
    it { should belong_to(:molde).optional }
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

  describe "peca_molde_uniqueness_for_organized_corte" do
    let(:molde) { create(:molde) }
    let(:peca) { create(:peca) }
    let(:modelo) { create(:modelo) }

    it "allows first organized corte with a peca for a molde" do
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde
      expect(corte1).to be_valid
    end

    it "rejects second organized corte with same peca for same molde" do
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte2.moldes << molde
      expect(corte2).not_to be_valid
      expect(corte2.errors[:peca_id]).to include(a_string_matching(/já está em uso/))
    end

    it "allows same peca for different moldes" do
      molde2 = create(:molde)
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte2.moldes << molde2
      expect(corte2).to be_valid
    end

    it "does not block different pecas for same molde" do
      peca2 = create(:peca)
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = create(:arquivo, :corte, organized: true, peca: peca2, modelo: modelo)
      corte2.moldes << molde
      expect(corte2).to be_valid
    end

    it "ignores validation when not corte category" do
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      arte = create(:arquivo, category: "artes", organized: true, peca: peca)
      arte.moldes << molde
      expect(arte).to be_valid
    end

    it "does not block when arquivo has no linked moldes" do
      # Intentional, not a gap: the constraint is scoped per molde (peca X
      # can't be organized-corte twice for the SAME molde). An arquivo with
      # no molde linked yet has no molde to conflict on — the check runs
      # again once a molde is actually attached, see
      # "POST /arquivos/:id/add_molde" in spec/requests/arquivos_spec.rb.
      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = build(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      expect(corte2).to be_valid
    end

    context "with peca_occupied_for_moldes? called with an explicit peca_id" do
      it "checks the given peca_id instead of self.peca_id" do
        peca2 = create(:peca)
        corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
        corte1.moldes << molde

        corte2 = create(:arquivo, :corte, peca: peca2, modelo: modelo)
        corte2.moldes << molde

        expect(corte2.peca_occupied_for_moldes?(peca_id: peca.id)).to be true
        expect(corte2.peca_occupied_for_moldes?(peca_id: peca2.id)).to be false
      end

      it "returns false for a non-corte arquivo regardless of peca_id" do
        corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
        corte1.moldes << molde

        arte = create(:arquivo, category: "artes")
        arte.moldes << molde

        expect(arte.peca_occupied_for_moldes?(peca_id: peca.id)).to be false
      end
    end

    context "with conflicting_corte class method" do
      it "returns the conflicting arquivo" do
        corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
        corte1.moldes << molde

        result = described_class.conflicting_corte(peca_id: peca.id, molde: molde)
        expect(result).to eq(corte1)
      end

      it "returns nil when no conflict exists" do
        result = described_class.conflicting_corte(peca_id: peca.id, molde: molde)
        expect(result).to be_nil
      end

      it "returns nil when peca_id is blank" do
        result = described_class.conflicting_corte(peca_id: nil, molde: molde)
        expect(result).to be_nil
      end

      it "returns nil when molde is nil" do
        result = described_class.conflicting_corte(peca_id: peca.id, molde: nil)
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

  # Regression (28/09/2026): several moldes share a modelo, each with its own
  # cortes; the modelo's first corte was taken as every molde's corte.
  describe ".cortes_do_molde / #corte_via_molde" do
    let(:modelo) { create(:modelo) }
    let(:lateral) { create(:peca, nome: "Lateral") }
    let(:lingua) { create(:peca, nome: "Língua") }
    let(:outro_molde) { create(:molde, modelo: modelo, sufixo: "21-24") }
    let(:molde) { create(:molde, modelo: modelo, sufixo: "28-29") }

    def corte(peca, *moldes)
      create(:arquivo, :corte, organized: true, modelo: modelo, peca: peca).tap { |c| moldes.each { |m| c.moldes << m } }
    end

    it "takes the cortes linked to the molde, not the whole modelo's" do
      corte(lateral, outro_molde)
      meu = corte(lateral, molde)
      expect(described_class.cortes_do_molde(molde)).to contain_exactly(meu)
    end

    it "falls back to the modelo's cortes of the molde's client when none is linked to the molde" do
      solto = create(:arquivo, :corte, organized: true, modelo: modelo, client: molde.client)
      expect(described_class.cortes_do_molde(molde)).to contain_exactly(solto)
    end

    # Regression (Etapa 1.1, 3/5): the official "Tenis" is every client's, so
    # the fallback took another client's corte (and its sizes) for an arte.
    it "never falls back to another client's corte of the same modelo" do
      create(:arquivo, :corte, organized: true, modelo: modelo, client: create(:client))
      create(:arquivo, :corte, organized: true, modelo: modelo, client: nil)
      expect(described_class.cortes_do_molde(molde)).to be_empty
    end

    it "picks the corte of the arte's own peça, else the first" do
      c_lingua = corte(lingua, molde)
      c_lateral = corte(lateral, molde)
      expect(create(:arquivo, molde: molde, peca: lateral).corte_via_molde).to eq(c_lateral)
      expect(create(:arquivo, molde: molde).corte_via_molde).to eq(c_lingua)
    end

    # Guessing lateral vs língua would assign a wrong size; the user picks it.
    it "#corte_inequivoco_via_molde is nil when several cortes and no peça" do
      corte(lingua, molde)
      corte(lateral, molde)
      expect(create(:arquivo, molde: molde).corte_inequivoco_via_molde).to be_nil
    end
  end
end
