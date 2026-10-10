# Changing one's own password — anyone signed in, and forced after a
# provisional password (User#trocar_senha, Authentication#exigir_troca_de_senha).
class SenhasController < ApplicationController
  nao_le_registros
  def edit
  end

  # The current password is asked unless it is the provisional one just used
  # to sign in.
  def update
    user = Current.user
    return redirect_to edit_senha_path, alert: "Current password is wrong." unless user.trocar_senha? || user.authenticate(params[:senha_atual].to_s)

    user.trocar_senha!(params.require(:nova_senha))
    redirect_to root_path, notice: "Password changed."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_senha_path, alert: e.record.errors.full_messages.to_sentence
  end
end
