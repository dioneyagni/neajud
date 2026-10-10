class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  nao_le_registros
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))
    if user && !user.ativo?
      redirect_to new_session_path, alert: "This account is deactivated. Ask the company owner."
    elsif user&.cliente&.excluido?
      redirect_to new_session_path, alert: "#{user.cliente.name}'s access is closed. Ask the company."
    elsif user
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
