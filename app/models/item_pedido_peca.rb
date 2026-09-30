# One piece (lateral, língua…) of the modelo an ItemPedido orders.
#   arquivo nil          → :pendente  (no arte yet; blocks confirming the pedido)
#   incluida true        → :incluida  (goes to production)
#   incluida false       → :excluida  (unchecked; the pedido goes to production
#                                      without this piece)
# peca nil means the arte's piece is unknown ("Sem peça").
class ItemPedidoPeca < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  belongs_to :item_pedido
  belongs_to :arquivo, optional: true
  belongs_to :peca, optional: true
  recusa_excluido :arquivo, :peca

  validates :peca_id, uniqueness: { scope: :item_pedido_id }, allow_nil: true

  scope :pendentes, -> { where(arquivo_id: nil) }
  scope :para_producao, -> { where.not(arquivo_id: nil).where(incluida: true) }

  # Usage: item.item_pedido_pecas.first.estado # => :incluida
  def estado
    return :pendente if arquivo.nil?

    incluida ? :incluida : :excluida
  end
end
