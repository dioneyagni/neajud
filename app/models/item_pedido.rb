class ItemPedido < ApplicationRecord
  self.table_name = "itens_pedido"

  belongs_to :pedido
  belongs_to :arquivo
  belongs_to :materia_prima, optional: true
  has_many :grades, class_name: "ItemPedidoGrade", dependent: :destroy

  validates :uuid, uniqueness: true

  before_validation :generate_uuid, on: :create

  def to_param
    uuid
  end

  def quantidade_total
    grades.sum(:quantidade)
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
