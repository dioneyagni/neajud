require "rails_helper"

RSpec.describe Molde do
  # Etapa 1.1 (4/5): code NNN-ABR per client + free suffix.
  describe "code and name" do
    let(:mks) { create(:client, name: "MKS") }
    let(:tenis) { create(:modelo, nome: "Tenis", abreviacao: "TNS") }
    let(:jogging) { create(:modelo, nome: "Jogging", abreviacao: "JGG") }

    it "numbers the client's moldes of every category and assembles the name" do
      primeiro = Molde.create!(client: mks, modelo: tenis)
      segundo = Molde.create!(client: mks, modelo: jogging, sufixo: "NB")
      outro_cliente = Molde.create!(client: create(:client), modelo: tenis)
      expect([ primeiro.nome, segundo.nome, outro_cliente.nome ]).to eq([ "001-TNS", "002-JGG NB", "001-TNS" ])
      expect(segundo.codigo).to eq("002-JGG")
    end

    it "never reuses a number, not even a trashed molde's" do
      Molde.create!(client: mks, modelo: tenis).excluir!(changed_by: "10.0.0.1")
      expect(Molde.create!(client: mks, modelo: tenis).numero).to eq(2)
    end

    it "keeps the number and follows the modelo's abbreviation (002-TNS → 002-JGG)" do
      Molde.create!(client: mks, modelo: tenis)
      molde = Molde.create!(client: mks, modelo: tenis, sufixo: "Furado")
      molde.update!(modelo: jogging)
      expect(molde.reload.nome).to eq("002-JGG Furado")
      molde.update!(sufixo: "Velcro")
      expect(molde.reload.nome).to eq("002-JGG Velcro")
    end

    it "needs a modelo to be created (the code needs its abbreviation)" do
      molde = Molde.new(client: mks)
      expect(molde).not_to be_valid
      expect(molde.errors[:modelo].first).to include("the code needs its abbreviation")
    end

    it "needs a client" do
      expect(Molde.new(modelo: tenis)).not_to be_valid
    end

    it "keeps its client once created" do
      molde = Molde.create!(client: mks, modelo: tenis)
      molde.client = create(:client)
      expect(molde).not_to be_valid
      expect(molde.errors[:client].first).to include("the code 001-TNS is in that client's sequence")
    end

    it "updates the stored name when the abbreviation changes in the official list" do
      molde = Molde.create!(client: mks, modelo: tenis, sufixo: "Furado")
      tenis.update_columns(abreviacao: "TEN")
      molde.reload.atualizar_nome!
      expect(molde.reload.nome).to eq("001-TEN Furado")
    end
  end

  describe "variation (variacao_de)" do
    let(:mks) { create(:client, name: "MKS") }
    let(:lateral) { create(:peca, nome: "Lateral") }
    let(:lingua) { create(:peca, nome: "Língua") }
    let(:base) { create(:molde, client: mks, sufixo: nil, tamanho_inicial: "24", tamanho_final: "34", partes: [ lateral, lingua ]) }

    before do
      base.molde_pecas.find_by(peca: lingua).update!(needs_cut: false)
      base.molde_pecas.find_by(peca: lateral).update!(pecas_por_par: 4, espelhada: true)
      create(:arquivo, :corte, organized: true, peca: lingua).moldes << base
    end

    it "is born with the base's modelo, grade, parts (cut flag, pieces per pair, mirrored) and corte links" do
      furado = Molde.create!(client: mks, variacao_de: base, sufixo: "Furado")
      expect([ furado.modelo, furado.grade.values_at(0, -1) ]).to eq([ base.modelo, %w[24 34] ])
      expect(furado.molde_pecas.map { |p| [ p.peca.nome, p.needs_cut, p.pecas_por_par, p.espelhada ] }).to eq([ [ "Lateral", true, 4, true ], [ "Língua", false, 2, false ] ])
      expect(furado.vinculated_arquivos).to eq(base.vinculated_arquivos)
      expect(furado.nome).to eq("002-#{base.modelo.abreviacao} Furado")
    end

    # "O cliente usando o corte de outro": the variation follows its own
    # client's numbering and points at the base's cortes.
    it "can be of another client's molde, numbered in its own client" do
      nesk = create(:client, name: "NESK")
      variacao = Molde.create!(client: nesk, variacao_de: base)
      expect(variacao.numero).to eq(1)
      expect(variacao.vinculated_arquivos).to eq(base.vinculated_arquivos)
    end

    it "leaves out trashed parts and cortes, and keeps the base fixed afterwards" do
      lateral.excluir!(changed_by: "10.0.0.1")
      base.vinculated_arquivos.first.excluir!(changed_by: "10.0.0.1")
      variacao = Molde.create!(client: mks, variacao_de: base)
      expect(variacao.molde_pecas.map { |p| p.peca.nome }).to eq([ "Língua" ])
      expect(variacao.vinculated_arquivos).to be_empty
      variacao.variacao_de = create(:molde)
      expect(variacao).not_to be_valid
    end
  end

  describe ".for_client" do
    it "returns moldes for a given client" do
      molde = create(:molde)
      expect(Molde.for_client(molde.client_id)).to include(molde)
    end
  end

  describe ".search" do
    it "finds moldes by suffix or code" do
      molde = create(:molde, sufixo: "Air Max")
      expect(Molde.search("Air")).to include(molde)
      expect(Molde.search(molde.codigo)).to include(molde)
    end
  end

  # Etapa 1.1 (3/5): the molde uses a stretch of its produto's grade; its
  # parts are its own (no copy from the category any more).
  describe "grade interval" do
    let(:client) { create(:client) }
    let(:calcado) { create(:modelo, produto: create(:produto, grade: (18..46).map(&:to_s))) }
    let(:banner) { create(:modelo, produto: create(:produto, grade: [])) }

    def molde(modelo: calcado, de: nil, ate: nil)
      Molde.new(client: client, modelo: modelo, tamanho_inicial: de, tamanho_final: ate)
    end

    it "accepts a stretch of the produto's grade and lists it" do
      m = molde(de: "24", ate: "27")
      expect(m).to be_valid
      expect(m.grade).to eq(%w[24 25 26 27])
    end

    it "accepts no interval at all (chosen later)" do
      expect(molde).to be_valid
      expect(molde.grade).to eq([])
    end

    it "refuses sizes outside the grade, a reversed stretch, or only one end" do
      expect(molde(de: "17", ate: "20")).not_to be_valid
      reverso = molde(de: "30", ate: "24")
      expect(reverso).not_to be_valid
      expect(reverso.errors[:tamanho_final].first).to include("\"30\"–\"24\" is not a stretch of 18–46")
      expect(molde(de: "24")).not_to be_valid
    end

    it "refuses an interval when the produto has no grade (Banner)" do
      m = molde(modelo: banner, de: "P", ate: "G")
      expect(m).not_to be_valid
      expect(m.errors[:tamanho_inicial].first).to include("has none")
    end
  end
end
