# One link of an arte to a modelo/peça made from a pedido's pending piece
# ("Escolher arte"). from_modelo is set when the arte was moved from another
# modelo — the move the user had to confirm. Names are copied so the history
# stays readable after a modelo is deleted (the ids are then nullified).
class ArquivoVinculoLog < ApplicationRecord
  include GeraUuid
  belongs_to :arquivo
  belongs_to :from_modelo, class_name: "Modelo", optional: true
  belongs_to :to_modelo, class_name: "Modelo", optional: true
  belongs_to :peca, optional: true
  belongs_to :pedido, optional: true
  belongs_to :user, optional: true

  validates :to_modelo_nome, presence: true

  # Usage: log.mudanca? # => true when the arte left another modelo
  def mudanca?
    from_modelo_nome.present?
  end
end
