# "Enviar para aprovação": the team sent this version of an arte to the
# client (Etapa 0.5, 4/4). Only from then on does the arte wait for approval
# (badge + "register approval"); without it nothing shows. Per version.
class SolicitacaoAprovacao < ApplicationRecord
  self.table_name = "solicitacoes_aprovacao"

  include GeraUuid
  include ReferenciaAtiva
  include VersaoDeArte
  include Cancelavel

  belongs_to :user
  recusa_excluido :arquivo
end
