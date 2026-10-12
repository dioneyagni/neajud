# The client asked for changes to an arte, in the system (Etapa 2.8, 4a,
# decided 12/10/2026): the note says what. It photographs the arte like a
# request or an approval (VersaoDeArte) and holds the arte at "alteração
# pedida" until the team sends it for approval again (Aprovavel).
class AlteracaoArte < ApplicationRecord
  self.table_name = "alteracoes_arte"

  include GeraUuid
  include ReferenciaAtiva
  include VersaoDeArte
  include Cancelavel

  belongs_to :user
  recusa_excluido :arquivo

  validates :recado, presence: { message: "can't be blank: say what to change" }
end
