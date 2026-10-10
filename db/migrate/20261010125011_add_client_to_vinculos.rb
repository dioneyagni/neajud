# Etapa 2.8 (1/5, decided 10/10/2026): a vínculo of the "cliente final" kind
# is tied to one Client of this instance; the visibility policy shows that
# person only what is the client's. Blank = the empresa's own team.
class AddClientToVinculos < ActiveRecord::Migration[8.1]
  def change
    add_reference :vinculos, :client, foreign_key: true, null: true
  end
end
