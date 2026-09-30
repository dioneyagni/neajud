# One link of an arte to a molde/peça made from a pedido's pending piece
# ("Escolher arte"). from_molde is set when the arte was moved from another
# molde — the move the user had to confirm. Names are copied so the history
# stays readable after a molde is deleted (the ids are then nullified).
class ArquivoVinculoLog < ApplicationRecord
  include GeraUuid
  belongs_to :arquivo
  belongs_to :from_molde, class_name: "Molde", optional: true
  belongs_to :to_molde, class_name: "Molde", optional: true
  belongs_to :peca, optional: true
  belongs_to :pedido, optional: true
  belongs_to :user, optional: true

  validates :to_molde_nome, presence: true

  # Usage: log.mudanca? # => true when the arte left another molde
  def mudanca?
    from_molde_nome.present?
  end
end
