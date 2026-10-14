class ItemPedidoGrade < ApplicationRecord
  self.table_name = "itens_pedido_grade"

  belongs_to :item_pedido

  validates :tamanho_nome, presence: true
  validates :quantidade, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :tamanho_nome, uniqueness: { scope: :item_pedido_id }
  # Etapa 2.6b1: a DTF line's own extra rows; blank = the pedido's.
  validates :fileiras_extras, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
end
