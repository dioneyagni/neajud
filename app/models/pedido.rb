class Pedido < ApplicationRecord
  belongs_to :client, optional: true
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :destroy

  validates :uuid, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[rascunho confirmado cancelado] }

  before_validation :generate_uuid, on: :create

  scope :rascunhos, -> { where(status: "rascunho") }
  scope :confirmados, -> { where(status: "confirmado") }

  def to_param
    uuid
  end

  def total_itens
    itens_pedido.left_joins(:grades).sum("COALESCE(itens_pedido_grade.quantidade, 0)")
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
