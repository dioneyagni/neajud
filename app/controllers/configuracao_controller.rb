# First access (Etapa 0.5): while the instance has no user, every page leads
# here; creating the empresa + first dono closes this screen for good.
class ConfiguracaoController < ApplicationController
  allow_unauthenticated_access
  nao_le_registros
  before_action :recusar_se_configurada

  def new
    @user = User.new
  end

  def create
    @user = ConfiguracaoInicialService.call(**configuracao_params)
    return render :new, status: :unprocessable_content unless @user.persisted?

    start_new_session_for @user
    redirect_to root_path, notice: "Welcome, #{@user.nome}! #{Empresa.atual.nome} is ready."
  end

  private

  def recusar_se_configurada
    redirect_to new_session_path if User.exists?
  end

  def configuracao_params
    params.expect(configuracao: %i[empresa_nome nome email_address password]).to_h.symbolize_keys
  end
end
