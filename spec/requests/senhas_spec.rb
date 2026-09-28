require "rails_helper"

RSpec.describe "Senha", type: :request, sem_login: true do
  let!(:user) { create(:vinculo, user: create(:user, email_address: "ana@x.com")).user }

  def entrar(senha)
    post session_path, params: { email_address: "ana@x.com", password: senha }
  end

  it "after a provisional password, nothing opens until it is changed" do
    user.definir_senha_provisoria!("provisoria-123")
    entrar("provisoria-123")
    get pedidos_path
    expect(response).to redirect_to(edit_senha_path)
    get edit_senha_path
    expect(response.body).not_to include("Current password")
    patch senha_path, params: { nova_senha: "minha-senha-123" }
    expect(user.reload.trocar_senha).to be false
    get pedidos_path
    expect(response).to have_http_status(:ok)
  end

  it "otherwise asks for the current password" do
    entrar("senha-segura-123")
    patch senha_path, params: { senha_atual: "errada-errada", nova_senha: "minha-senha-123" }
    expect(flash[:alert]).to eq("Current password is wrong.")
    patch senha_path, params: { senha_atual: "senha-segura-123", nova_senha: "minha-senha-123" }
    expect(user.reload.authenticate("minha-senha-123")).to be_truthy
  end

  it "a deactivated user can't sign in, and loses an open session" do
    entrar("senha-segura-123")
    user.update_columns(desativado_em: Time.current)
    get pedidos_path
    expect(response).to redirect_to(new_session_path)
    entrar("senha-segura-123")
    expect(flash[:alert]).to include("deactivated")
  end
end
