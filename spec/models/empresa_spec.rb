require "rails_helper"
require_relative "../support/construcoes"

RSpec.describe Empresa do
  it "allows only one empresa per instance and names the existing one" do
    create(:empresa, nome: "Sublimação X")
    segunda = build(:empresa, nome: "Outra")
    expect(segunda).not_to be_valid
    expect(segunda.errors[:base].first).to include("Sublimação X", "at most one")
  end

  it ".atual is the instance's empresa, nil before setup" do
    expect(Empresa.atual).to be_nil
    empresa = create(:empresa)
    expect(Empresa.atual).to eq(empresa)
  end

  # Etapa 2.2 (1/3): the dono's production parameters.
  it "starts with a 1,60 m paper and a band of -10% / +25%, refusing nonsense" do
    empresa = Empresa.atual || create(:empresa)
    expect(empresa.attributes.values_at("largura_papel_mm", "tolerancia_abaixo_pct", "tolerancia_acima_pct")).to eq([ 1600, 10, 25 ])
    empresa.assign_attributes(largura_papel_mm: 0, tolerancia_abaixo_pct: 101)
    expect(empresa).not_to be_valid
    expect(empresa.errors.attribute_names).to contain_exactly(:largura_papel_mm, :tolerancia_abaixo_pct)
  end

  # Etapa 2.3: the paper is a material; its width replaces the typed one.
  it "fits the artes on the default paper's width, else the typed one, and takes only a papel as default" do
    empresa = Empresa.atual || create(:empresa)
    expect(empresa.largura_papel_efetiva_mm).to eq(1600)
    papel = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Papel"), cor_material: CorMaterial.create!(nome: "Branco"), largura: "1,10 m", gramatura: "40g", tipo: "papel")
    empresa.update!(papel_padrao: papel)
    expect(empresa.largura_papel_efetiva_mm).to eq(1100)
    papel.update!(tipo: "tecido")
    expect(empresa.reload).not_to be_valid
    expect(empresa.errors[:papel_padrao].first).to include("is a tecido; expected a material of type papel")
  end

  # Etapa 2.3d1: the DTF film is a material too; its width replaces the
  # typed one and redoes every etiqueta's fit.
  it "fits the etiquetas on the default film's width, else the typed one, and takes only a filme_dtf as default" do
    empresa = Empresa.atual || create(:empresa)
    expect([ empresa.largura_filme_dtf_efetiva_mm, empresa.largura_util_filme_dtf_mm ]).to eq([ 600, 570 ])
    filme = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Filme DTF"), cor_material: CorMaterial.create!(nome: "Branco"), largura: "58 cm", gramatura: "75mic", tipo: "filme_dtf")
    expect(EncaixeDaEtiqueta).to receive(:atualizar_todas!)
    empresa.update!(filme_dtf_padrao: filme)
    expect([ empresa.largura_filme_dtf_efetiva_mm, empresa.largura_util_filme_dtf_mm ]).to eq([ 580, 550 ])
    filme.update!(tipo: "filme")
    expect(empresa.reload).not_to be_valid
    expect(empresa.errors[:filme_dtf_padrao].first).to include("is a filme; expected a material of type filme_dtf")
  end

  # Etapa 2.4: the cost per pair needs both costs.
  it "knows when the costs per meter printed and per piece cut are set, refusing negative ones" do
    empresa = Empresa.new(nome: "Neajud")
    expect(empresa.custos_definidos?).to be(false)
    empresa.assign_attributes(custo_impressao_metro: 4.5, custo_corte_peca: 0)
    expect(empresa.custos_definidos?).to be(true)
    empresa.custo_corte_peca = -1
    expect(empresa).not_to be_valid
  end

  # Dublagem 5b1a (Q2d, Q3c): 8 layers to start, at least 2; lowering it is
  # refused while an active construção has more, naming it.
  describe "the most layers of a construção" do
    let(:empresa) { Empresa.atual || create(:empresa) }

    def construcao_de(camadas)
      oxford = material_de_dublagem("Oxford")
      filme = material_de_dublagem("Filme", tipo: "filme", micras: 35)
      montar_construcao([ oxford, "trama" ], *([ [ oxford, filme ] ] * (camadas - 1))).tap(&:save!)
    end

    it "starts at 8 and is never below 2" do
      expect(empresa.maximo_de_camadas).to eq(8)
      expect(empresa.update(maximo_de_camadas: 1)).to be(false)
    end

    it "refuses to go below an active construção, until it is in the trash" do
      construcao = construcao_de(3)

      expect(empresa.update(maximo_de_camadas: 2)).to be(false)
      expect(empresa.errors[:base].first).to eq("o máximo de camadas não baixa para 2: #{construcao.nome} (3) tem mais; mande para a lixeira ou deixe o máximo maior")
      construcao.excluir!(changed_by: "127.0.0.1")
      expect(empresa.reload.update(maximo_de_camadas: 2)).to be(true)
    end
  end
end
