require "rails_helper"

RSpec.describe GestaoDeUsuarios do
  let(:dono) { create(:vinculo).user }
  let(:admin_funcao) { create(:funcao, nome: "Admin", niveis: { "pedidos" => 3, "artes" => 2 }, acoes: %w[gerenciar_usuarios]) }
  let(:admin) { create(:vinculo, funcao: admin_funcao).user }
  let(:designer_funcao) { create(:funcao, nome: "Designer", niveis: { "artes" => 2 }) }
  let(:designer) { create(:vinculo, funcao: designer_funcao).user }

  describe "#pode_gerir?" do
    it "lets a manager manage non-donos, and only a dono manage donos" do
      expect(described_class.new(admin).pode_gerir?(designer)).to be true
      expect(described_class.new(admin).pode_gerir?(dono)).to be false
      expect(described_class.new(dono).pode_gerir?(admin)).to be true
    end

    it "needs the gerenciar_usuarios action" do
      expect(described_class.new(designer).pode_gerir?(admin)).to be false
    end
  end

  describe "#erros_de_atribuicao" do
    it "refuses the Dono função from a non-dono" do
      expect(described_class.new(admin).erros_de_atribuicao(designer, create(:funcao_dono), {})).to eq([ "only a dono can give the Dono função" ])
    end

    it "refuses giving more than the manager has, naming what" do
      erros = described_class.new(admin).erros_de_atribuicao(designer, designer_funcao, { "niveis" => { "artes" => 3, "lixeira" => 1 }, "acoes" => %w[baixar_producao] })
      expect(erros).to contain_exactly(*%w[artes lixeira baixar_producao].map { |item| "you can't give more than you have (#{item})" })
    end

    it "allows up to what the manager has" do
      expect(described_class.new(admin).erros_de_atribuicao(designer, designer_funcao, { "niveis" => { "pedidos" => 3 } })).to eq([])
    end

    it "lets the dono give anything, but never leave the empresa without a dono" do
      expect(described_class.new(dono).erros_de_atribuicao(designer, Funcao.dono, {})).to eq([])
      expect(described_class.new(dono).erros_de_atribuicao(dono, designer_funcao, {})).to eq([ "#{dono.nome} is the only active dono; the empresa must keep one" ])
    end

    it "requires a função" do
      expect(described_class.new(dono).erros_de_atribuicao(designer, nil, {})).to eq([ "choose a função" ])
    end
  end

  describe "#erros_para_desativar" do
    it "refuses deactivating yourself, a dono (as non-dono) and the last dono" do
      expect(described_class.new(admin).erros_para_desativar(admin)).to eq([ "you can't deactivate yourself" ])
      expect(described_class.new(admin).erros_para_desativar(dono)).to eq([ "only a dono can deactivate a dono" ])
      outro_dono = create(:vinculo).user
      outro_dono.desativar!(por: dono)
      expect(described_class.new(outro_dono.reload.tap(&:reativar!)).erros_para_desativar(dono)).to eq([])
    end

    it "keeps the last active dono" do
      segundo = create(:vinculo).user
      segundo.desativar!(por: dono)
      expect(described_class.new(dono).erros_para_desativar(dono)).to eq([ "you can't deactivate yourself" ])
      expect(described_class.new(segundo.tap(&:reativar!)).erros_para_desativar(dono)).to eq([])
    end
  end
end
