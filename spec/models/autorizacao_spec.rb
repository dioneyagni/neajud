require "rails_helper"

RSpec.describe Autorizacao do
  let(:funcao) { build(:funcao, niveis: { "pedidos" => 2, "lixeira" => 1 }, acoes: %w[baixar_producao]) }

  it "reads the função's level per área; each level includes the ones before" do
    autorizacao = described_class.new(funcao)
    expect(autorizacao.nivel(:pedidos)).to eq(2)
    expect([ autorizacao.pode?(:pedidos, :ver), autorizacao.pode?(:pedidos, :editar), autorizacao.pode?(:pedidos, :excluir) ]).to eq([ true, true, false ])
    expect(autorizacao.pode?(:clientes, :ver)).to be false
  end

  it "lets acessos_extras raise a level or add an action, never lower one" do
    autorizacao = described_class.new(funcao, { "niveis" => { "pedidos" => 0, "clientes" => 3 }, "acoes" => %w[gerenciar_usuarios] })
    expect([ autorizacao.nivel(:pedidos), autorizacao.nivel(:clientes) ]).to eq([ 2, 3 ])
    expect(autorizacao.pode_acao?(:gerenciar_usuarios)).to be true
  end

  it "gives the dono everything, lixeira up to restaurar (2)" do
    dono = described_class.new(build(:funcao, dono: true))
    expect(dono).to be_dono
    expect([ dono.nivel(:artes), dono.nivel(:lixeira) ]).to eq([ 3, 2 ])
    expect(dono.pode_acao?(:gerenciar_usuarios)).to be true
  end

  it "allows nothing without a função" do
    expect(described_class.new(nil).pode?(:pedidos, :ver)).to be false
  end

  it "fails loudly on a typo instead of quietly denying" do
    expect { described_class.new(funcao).pode?(:pedido, :ver) }.to raise_error(ArgumentError, /unknown área "pedido"; expected one of pedidos/)
    expect { described_class.new(funcao).pode?(:pedidos, :apagar) }.to raise_error(ArgumentError, /unknown level "apagar"/)
    expect { described_class.new(funcao).pode_acao?(:voar) }.to raise_error(ArgumentError, /unknown action "voar"/)
  end

  describe ".erros_da_grade" do
    it "names unknown áreas, out-of-range levels (lixeira stops at 2) and unknown actions" do
      erros = described_class.erros_da_grade({ "cozinha" => 1, "lixeira" => 3, "pedidos" => "x" }, %w[voar])
      expect(erros.join(" | ")).to include('"cozinha"', "3 for lixeira; expected 0 to 2", '"x" for pedidos', '"voar"')
    end

    it "is empty for a valid grid" do
      expect(described_class.erros_da_grade({ "pedidos" => 3, "lixeira" => 2 }, %w[baixar_producao])).to eq([])
    end
  end

  describe ".erros_para_cliente" do
    it "names the team's áreas and actions a client's access can't have" do
      erros = described_class.erros_para_cliente({ "lixeira" => 1, "pedidos" => 3 }, %w[aprovar_arte gerenciar_usuarios])
      expect(erros).to contain_exactly(include("lixeira"), include("gerenciar_usuarios"))
      expect(described_class.erros_para_cliente({ "lixeira" => 0 }, %w[aprovar_arte])).to eq([])
    end
  end
end
