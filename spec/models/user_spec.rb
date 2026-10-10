require "rails_helper"

RSpec.describe User do
  it "normalizes the email and gets a uuid" do
    user = create(:user, email_address: "  Ana@Example.COM ")
    expect(user).to have_attributes(email_address: "ana@example.com", uuid: be_present)
  end

  it "requires a name, a valid unique email and an 8+ char password" do
    create(:user, email_address: "ana@example.com")
    user = build(:user, nome: "", email_address: "ANA@example.com", password: "short")
    expect(user).not_to be_valid
    expect(user.errors.attribute_names).to include(:nome, :email_address, :password)
  end

  it "keeps cloud_user_uuid optional but unique" do
    create(:user, cloud_user_uuid: "cloud-1")
    expect(build(:user, cloud_user_uuid: nil)).to be_valid
    expect(build(:user, cloud_user_uuid: "cloud-1")).not_to be_valid
  end

  describe "deactivation" do
    it "blocks, ends sessions, leaves the user in place, and reactivates" do
      dono, user = create(:user), create(:user)
      user.sessions.create!
      user.desativar!(por: dono)
      expect(user.reload).to have_attributes(ativo?: false, desativado_por: dono)
      expect(user.sessions).to be_empty
      expect(User.ativos).not_to include(user)
      user.reativar!
      expect(user.reload).to be_ativo
    end
  end

  describe "passwords" do
    it "a provisional password forces a change and ends sessions" do
      user = create(:user)
      user.sessions.create!
      user.definir_senha_provisoria!("provisoria-123")
      expect(user.reload).to have_attributes(trocar_senha: true)
      expect(user.sessions).to be_empty
      user.trocar_senha!("minha-senha-123")
      expect(user.reload.trocar_senha).to be false
      expect(user.authenticate("minha-senha-123")).to be_truthy
    end
  end

  describe "#autorizacao" do
    it "comes from its vínculo's função" do
      vinculo = create(:vinculo, funcao: create(:funcao, niveis: { "artes" => 2 }))
      expect(vinculo.user.autorizacao.pode?(:artes, :editar)).to be true
      expect(vinculo.user.autorizacao.pode?(:artes, :excluir)).to be false
    end

    it "allows nothing without a vínculo" do
      expect(create(:user).autorizacao.pode?(:pedidos, :ver)).to be false
    end
  end

  # Etapa 2.8 (2/5).
  describe "scopes for clientes finais" do
    let(:client) { create(:client) }
    let!(:equipe) { create(:vinculo).user }
    let!(:cliente_final) { create(:vinculo, client: client).user }

    it ".da_equipe leaves out clientes finais" do
      expect(described_class.da_equipe).to contain_exactly(equipe)
    end

    it ".com_acesso leaves out the deactivated and the clientes finais of a trashed client" do
      expect(described_class.com_acesso).to contain_exactly(equipe, cliente_final)
      client.excluir!(changed_by: "10.0.0.1")
      expect(described_class.com_acesso).to contain_exactly(equipe)
      equipe.desativar!(por: nil)
      expect(described_class.com_acesso).to be_empty
    end
  end
end
