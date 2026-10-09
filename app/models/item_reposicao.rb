# One line's missing pieces in a reposição (Etapa 2.2, 4/4; decided
# 08-09/10/2026): the exact piece to print and cut again — the file, part,
# DXF size, side and material of the original line — and how many. A
# reposição counts pieces, not pairs: one left lateral may be all that's
# missing.
#
# Usage: reposicao.itens_reposicao.sum(:pecas) # => 3
class ItemReposicao < ApplicationRecord
  self.table_name = "itens_reposicao"
  include GeraUuid

  belongs_to :pedido
  belongs_to :item_origem, class_name: "ItemPedido"
  belongs_to :arquivo
  belongs_to :peca, optional: true
  belongs_to :tamanho, optional: true
  belongs_to :materia_prima, optional: true

  validates :pecas, numericality: { only_integer: true, greater_than: 0 }
  validates :lado, inclusion: { in: LadoNaArte::LADOS, allow_nil: true }
end
