require "rails_helper"

RSpec.describe ConfiguracaoInicialService do
  let(:dados) { { empresa_nome: "Sublimação X", nome: "Ana", email_address: "ana@x.com", password: "senha-segura-123" } }

  it "creates the empresa, the default funções and the user as Dono" do
    user = described_class.call(**dados)
    expect(user).to be_persisted
    expect(Empresa.atual.nome).to eq("Sublimação X")
    expect(Funcao.pluck(:nome)).to match_array(Funcao::PADRAO.pluck(:nome))
    expect(user.vinculo.funcao).to eq(Funcao.dono)
  end

  it "creates nothing and reports every error when invalid" do
    user = described_class.call(**dados, empresa_nome: "", password: "x")
    expect(user).not_to be_persisted
    expect(user.errors.attribute_names).to include(:empresa_nome, :password)
    expect([ Empresa.count, User.count, Vinculo.count ]).to eq([ 0, 0, 0 ])
  end

  it "refuses once any user exists" do
    create(:user)
    expect { described_class.call(**dados) }.to raise_error(described_class::JaConfigurada, /\(1 user\(s\)\); expected none/)
  end
end
