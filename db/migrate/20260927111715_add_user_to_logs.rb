# Etapa 0.5 (1/3): "who did it" becomes the logged-in user. changed_by keeps
# the IP, the only "who" that older rows have.
class AddUserToLogs < ActiveRecord::Migration[8.1]
  def change
    add_reference :exclusao_logs, :user, foreign_key: true
    add_reference :arquivo_vinculo_logs, :user, foreign_key: true
    add_reference :arquivo_time_logs, :user, foreign_key: true
  end
end
