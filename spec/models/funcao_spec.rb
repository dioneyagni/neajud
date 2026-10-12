require "rails_helper"

RSpec.describe Funcao do
  it ".criar_padrao! creates the plan's funções with Dono as the system one" do
    described_class.criar_padrao!
    expect(described_class.order(:id).pluck(:nome)).to eq([ "Dono", "Admin", "Atendimento", "Designer", "Produção", "Cliente final" ])
    expect(described_class.dono.nome).to eq("Dono")
    expect(described_class.para_clientes.pluck(:nome)).to eq([ "Cliente final" ])
    expect(described_class.find_by(nome: "Produção").niveis).to include("pedidos" => 1, "lixeira" => 0)
  end

  # Etapa 2.8 (2/5): a cliente final never gets the trash nor the factory's actions.
  it "refuses the team's lixeira and actions in a função para clientes" do
    funcao = build(:funcao, :para_cliente, niveis: { "pedidos" => 1, "lixeira" => 1 }, acoes: %w[aprovar_arte ver_valores])
    expect(funcao).not_to be_valid
    expect(funcao.errors[:niveis]).to contain_exactly(include("lixeira"), include("ver_valores"))
    expect(build(:funcao, :para_cliente, niveis: { "pedidos" => 1 }, acoes: %w[aprovar_arte])).to be_valid
  end

  # Etapa 2.8 (4b): artes up to editar, the rest only ver.
  it "caps a função para clientes at what a client may have" do
    expect(build(:funcao, :para_cliente, niveis: { "artes" => 2, "pedidos" => 1 })).to be_valid
    expect(build(:funcao, :para_cliente, niveis: { "artes" => 3 }).tap(&:valid?).errors[:niveis]).to eq([ "a client's access can't go above editar in artes" ])
  end

  # Its vínculos were checked against the type when made.
  it "keeps a função's type after creation" do
    funcao = create(:funcao, :para_cliente)
    expect(funcao.update(para_cliente: false)).to be false
    expect(funcao.errors[:para_cliente].first).to include("can't change after creation")
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
