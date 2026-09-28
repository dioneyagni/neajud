require "rails_helper"

RSpec.describe CadastroDeUsuarioService do
  let(:dono) { create(:vinculo).user }
  let(:producao) { create(:funcao, nome: "Produção", niveis: { "pedidos" => 1 }) }
  let(:dados) do
    { nome: "João", email_address: "joao@x.com", funcao_uuid: producao.uuid, senha_provisoria: "provisoria-123",
      acessos_extras: { "niveis" => { "pedidos" => "2", "artes" => "0" }, "acoes" => [ "", "baixar_producao" ] } }
  end

  it "creates the user with a provisional password, the função and the extras" do
    user = described_class.call(gestor: dono, user: User.new, dados: dados)
    expect(user.errors).to be_empty
    expect(user.reload).to have_attributes(trocar_senha: true)
    expect(user.vinculo.funcao).to eq(producao)
    expect(user.vinculo.acessos_extras).to eq("niveis" => { "pedidos" => 2 }, "acoes" => %w[baixar_producao])
    expect(user.autorizacao.pode?(:pedidos, :editar)).to be true
  end

  it "requires a provisional password for a new user" do
    user = described_class.call(gestor: dono, user: User.new, dados: dados.merge(senha_provisoria: ""))
    expect(user.errors[:password]).to include("is required for a new user")
    expect(User.where(email_address: "joao@x.com")).to be_empty
  end

  it "updates função and extras without touching the password" do
    user = described_class.call(gestor: dono, user: User.new, dados: dados)
    digest = user.password_digest
    described_class.call(gestor: dono, user: user, dados: dados.except(:senha_provisoria).merge(acessos_extras: {}))
    expect(user.reload.password_digest).to eq(digest)
    expect(user.vinculo.acessos_extras).to eq("niveis" => {}, "acoes" => [])
  end

  it "saves nothing when the manager may not give it" do
    admin = create(:vinculo, funcao: create(:funcao, niveis: { "pedidos" => 1 }, acoes: %w[gerenciar_usuarios])).user
    user = described_class.call(gestor: admin, user: User.new, dados: dados)
    expect(user.errors[:base]).to include("you can't give more than you have (pedidos)", "you can't give more than you have (baixar_producao)")
    expect(User.where(email_address: "joao@x.com")).to be_empty
  end
end
