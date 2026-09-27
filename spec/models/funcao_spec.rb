require "rails_helper"

RSpec.describe Funcao do
  it ".criar_padrao! creates the plan's funções with Dono as the system one" do
    described_class.criar_padrao!
    expect(described_class.order(:id).pluck(:nome)).to eq(%w[Dono Admin Atendimento Designer Produção])
    expect(described_class.dono.nome).to eq("Dono")
    expect(described_class.find_by(nome: "Produção").niveis).to include("pedidos" => 1, "lixeira" => 0)
  end

  it "validates the grid" do
    funcao = build(:funcao, niveis: { "pedidos" => 7 })
    expect(funcao).not_to be_valid
    expect(funcao.errors[:niveis].first).to include("7 for pedidos")
  end

  it "keeps names unique, case-insensitively" do
    create(:funcao, nome: "Corte")
    expect(build(:funcao, nome: "corte")).not_to be_valid
  end

  # Editing the Dono função would let someone lock the owner out.
  it "never changes the Dono função" do
    dono = create(:funcao_dono)
    expect(dono.update(niveis: { "pedidos" => 0 })).to be false
    expect(dono.update(nome: "Chefe")).to be false
  end

  describe "#excluir!" do
    it "moves an unused função to the trash" do
      funcao = create(:funcao)
      funcao.excluir!(changed_by: "10.0.0.1")
      expect(funcao.reload).to be_excluido
    end

    it "refuses while someone has it, and for the Dono função" do
      em_uso = create(:vinculo, funcao: create(:funcao, nome: "Corte")).funcao
      expect { em_uso.excluir!(changed_by: "10.0.0.1") }.to raise_error(Funcao::EmUso, /"Corte" is used by 1 user/)
      expect { create(:funcao_dono).excluir!(changed_by: "10.0.0.1") }.to raise_error(Funcao::EmUso, /Dono/)
    end
  end
end
