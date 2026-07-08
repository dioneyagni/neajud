class ItemPedidoGrade < ApplicationRecord
  self.table_name = "itens_pedido_grade"

  belongs_to :item_pedido

  validates :tamanho_nome, presence: true
  validates :quantidade, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :tamanho_nome, uniqueness: { scope: :item_pedido_id }
end
