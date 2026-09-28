require "rails_helper"

RSpec.describe "Usuários", type: :request do
  let(:producao) { create(:funcao, nome: "Produção", niveis: { "pedidos" => 1 }) }

  def criar_joao
    post usuarios_path, params: { usuario: { nome: "João", email_address: "joao@x.com", funcao_uuid: producao.uuid, senha_provisoria: "provisoria-123",
                                             acessos_extras: { niveis: { pedidos: "2" }, acoes: [ "" ] } } }
    User.find_by!(email_address: "joao@x.com")
  end

  it "lists users with função, extras and status" do
    joao = criar_joao
    get usuarios_path
    expect(response.body).to include("João", "joao@x.com", "Produção", "Pedidos: Editar", "provisional password")
    joao.desativar!(por: @usuario_logado)
    get usuarios_path
    expect(response.body).to include("deactivated", "Reactivate")
  end

  it "creates a user from the form" do
    get new_usuario_path
    expect(response.body).to include("Provisional password", "Extra accesses")
    expect(criar_joao.vinculo.funcao).to eq(producao)
    expect(flash[:notice]).to include("João added")
  end

  it "shows the form again with the errors" do
    post usuarios_path, params: { usuario: { nome: "", email_address: "x", funcao_uuid: "", senha_provisoria: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("choose a função")
  end

  it "edits função and extras" do
    joao = criar_joao
    patch usuario_path(joao), params: { usuario: { nome: "João Silva", email_address: "joao@x.com", funcao_uuid: producao.uuid, acessos_extras: { niveis: { artes: "1" } } } }
    expect(joao.reload.nome).to eq("João Silva")
    expect(joao.vinculo.acessos_extras["niveis"]).to eq("artes" => 1)
  end

  it "resets the password, deactivates and reactivates" do
    joao = criar_joao
    joao.trocar_senha!("minha-senha-123")
    post redefinir_senha_usuario_path(joao), params: { senha_provisoria: "outra-provisoria" }
    expect(joao.reload).to have_attributes(trocar_senha: true)
    post desativar_usuario_path(joao)
    expect(joao.reload).not_to be_ativo
    post reativar_usuario_path(joao)
    expect(joao.reload).to be_ativo
  end

  it "refuses deactivating yourself" do
    post desativar_usuario_path(@usuario_logado)
    expect(flash[:alert]).to include("you can't deactivate yourself")
    expect(@usuario_logado.reload).to be_ativo
  end

  describe "as a manager who isn't the dono", sem_login: true do
    before { entrar_com_funcao(niveis: { "pedidos" => 1 }, acoes: %w[gerenciar_usuarios]) }

    # Managing a dono would let an admin lock the owner out.
    it "can't open a dono's page" do
      dono = create(:vinculo, funcao: create(:funcao_dono)).user
      get edit_usuario_path(dono)
      expect(response).to have_http_status(:forbidden)
    end

    it "can't offer the Dono função" do
      create(:funcao_dono)
      get new_usuario_path
      expect(response.body).not_to include(">Dono<")
    end
  end
end
