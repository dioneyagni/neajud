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

  # Everything that goes to production, by peça and tamanho. The single place
  # production reads from; see ProducaoPedidoService.
  # Usage: pedido.pecas_para_produzir.first.quantidades # => {"35"=>10}
  def pecas_para_produzir
    ProducaoPedidoService.call(self)
  end

  # Pieces without arte; while any exist the pedido cannot be confirmed.
  # Usage: pedido.pecas_pendentes.map { |p| p.peca&.nome } # => ["Língua"]
  def pecas_pendentes
    ItemPedidoPeca.pendentes.joins(:item_pedido).where(itens_pedido: { pedido_id: id })
                  .includes(:peca, item_pedido: :arquivo).order("itens_pedido.id", :position)
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
