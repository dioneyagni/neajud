require "rails_helper"

RSpec.describe "Autenticação", type: :request, sem_login: true do
  let(:senha) { "senha-segura-123" }

  describe "a new instance (no user yet)" do
    it "sends every page to the first-access setup" do
      get pedidos_path
      expect(response).to redirect_to(configuracao_path)
    end

    it "creates the empresa and the dono, signs them in" do
      post configuracao_path, params: { configuracao: { empresa_nome: "Sublimação X", nome: "Ana", email_address: "ana@x.com", password: senha } }
      expect(response).to redirect_to(root_path)
      expect(User.last.autorizacao).to be_dono
      get pedidos_path
      expect(response).to have_http_status(:ok)
    end

    it "shows the errors without creating anything" do
      post configuracao_path, params: { configuracao: { empresa_nome: "", nome: "Ana", email_address: "ana@x.com", password: senha } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Empresa nome")
      expect(User.count).to eq(0)
    end
  end

  describe "a configured instance" do
    let!(:user) { create(:vinculo, user: create(:user, email_address: "ana@x.com")).user }

    # The setup screen would let anyone create a second dono and take over.
    it "closes the setup screen for good" do
      get configuracao_path
      expect(response).to redirect_to(new_session_path)
      post configuracao_path, params: { configuracao: { empresa_nome: "X", nome: "Intruso", email_address: "i@x.com", password: senha } }
      expect(User.count).to eq(1)
    end

    it "sends signed-out visits to sign in and back to the page afterwards" do
      get pedidos_path
      expect(response).to redirect_to(new_session_path)
      post session_path, params: { email_address: "ANA@x.com", password: senha }
      expect(response).to redirect_to(pedidos_url)
    end

    it "refuses a wrong password" do
      post session_path, params: { email_address: "ana@x.com", password: "errada-errada" }
      expect(response).to redirect_to(new_session_path)
      get pedidos_path
      expect(response).to redirect_to(new_session_path)
    end

    it "signs out" do
      post session_path, params: { email_address: "ana@x.com", password: senha }
      delete session_path
      get pedidos_path
      expect(response).to redirect_to(new_session_path)
    end

    it "shows the user's name and Sign out in the header" do
      post session_path, params: { email_address: "ana@x.com", password: senha }
      get pedidos_path
      expect(response.body).to include(user.nome, "Sign out")
    end
  end

  # Etapa 2.8 (2/5): a cliente final's access.
  describe "a cliente final" do
    let(:client) { create(:client, name: "Calçados Alfa") }
    let!(:user) { create(:vinculo, client: client, user: create(:user, email_address: "bia@x.com")).user }

    it "starts on his pedidos, with his client's name in the header" do
      post session_path, params: { email_address: "bia@x.com", password: senha }
      expect(response).to redirect_to(pedidos_url)
      follow_redirect!
      expect(response.body).to include("Calçados Alfa")
    end

    it "goes to his pedidos after choosing his password" do
      user.update!(trocar_senha: true)
      post session_path, params: { email_address: "bia@x.com", password: senha }
      patch senha_path, params: { nova_senha: "minha-senha-bia-1" }
      expect(response).to redirect_to(pedidos_path)
    end

    # Trashing the client closes its people's access; restoring reopens it.
    it "can't sign in nor keep a session while his client is in the trash" do
      post session_path, params: { email_address: "bia@x.com", password: senha }
      client.excluir!(changed_by: "10.0.0.1")
      get pedidos_path
      expect(response).to redirect_to(new_session_path)
      post session_path, params: { email_address: "bia@x.com", password: senha }
      expect(flash[:alert]).to include("Calçados Alfa's access is closed")
      client.restaurar!(changed_by: "10.0.0.1")
      post session_path, params: { email_address: "bia@x.com", password: senha }
      expect(response).to redirect_to(pedidos_url)
    end
  end
end
