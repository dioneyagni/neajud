# Etapa 0.5: every page needs a signed-in user. Request specs sign in as a
# dono by default (a real POST /session, so the cookie is the app's own);
# tag a group `sem_login: true` to test the signed-out behavior.
module AutenticacaoHelpers
  # Usage: entrar_como(create(:user)) — the user gets a vínculo if missing.
  def entrar_como(user, password: "senha-segura-123")
    create(:vinculo, user: user) unless user.vinculos.exists?
    post session_path, params: { email_address: user.email_address, password: password }
    user
  end

  # Signs in as a user whose função has exactly these levels/actions.
  # Usage: entrar_com_funcao(niveis: { "pedidos" => 1 }, acoes: %w[baixar_producao])
  def entrar_com_funcao(niveis: {}, acoes: [])
    funcao = create(:funcao, niveis: niveis, acoes: acoes)
    entrar_como(create(:vinculo, funcao: funcao).user)
  end
end

# bcrypt at its cheapest: signing in happens in almost every request spec.
ActiveModel::SecurePassword.min_cost = true

RSpec.configure do |config|
  config.include AutenticacaoHelpers, type: :request
  config.before(type: :request) do |example|
    @usuario_logado = entrar_como(create(:user)) unless example.metadata[:sem_login]
  end
end
