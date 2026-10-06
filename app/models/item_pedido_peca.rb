# One part (lateral, língua…) of the arte an ItemPedido orders, and whether
# it goes to production:
#   incluida true  → :incluida (goes to production)
#   incluida false → :excluida (unchecked; the pedido goes without this part)
# Where each number of it comes from — and what is missing — is ResolucaoDoItem
# (Etapa 1.2, 3/3): the pedido reads the arte, so `arquivo` is only the file of
# the part when the item was added (shown nowhere since). peca nil means the
# part is unknown ("Sem peça").
class ItemPedidoPeca < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  belongs_to :item_pedido
  belongs_to :arquivo, optional: true
  belongs_to :peca, optional: true
  recusa_excluido :arquivo, :peca

  validates :peca_id, uniqueness: { scope: :item_pedido_id }, allow_nil: true

  # Usage: item.item_pedido_pecas.first.estado # => :incluida
  def estado
    incluida ? :incluida : :excluida
  end
end
