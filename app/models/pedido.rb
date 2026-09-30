class Pedido < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva

  belongs_to :client, optional: true
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :destroy
  has_many :arquivo_vinculo_logs, dependent: :nullify

  recusa_excluido :client
  validates :status, presence: true, inclusion: { in: %w[rascunho confirmado cancelado] }

  scope :rascunhos, -> { where(status: "rascunho") }
  scope :confirmados, -> { where(status: "confirmado") }

  def rotulo_lixeira
    "Pedido #{uuid.first(8)}"
  end

  # A draft that is not in the trash: the only state whose items and pieces
  # can still change.
  # Usage: <% if @pedido.editavel? %> … <% end %>
  def editavel?
    status == "rascunho" && !excluido?
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

  # What keeps this draft from being confirmed: pieces without arte, items
  # with total 0, checked pieces without corte. Empty = can confirm.
  # Usage: pedido.bloqueios_confirmacao.map(&:descricao)
  def bloqueios_confirmacao
    PedidoBloqueiosService.call(self)
  end
end
