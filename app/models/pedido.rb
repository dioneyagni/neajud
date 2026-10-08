class Pedido < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva

  belongs_to :client, optional: true
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :destroy
  has_many :arquivo_vinculo_logs, dependent: :nullify
  # Etapa 2.2 (2/3): what the factory has done, stage by stage.
  has_many :baixas_producao, class_name: "BaixaProducao", dependent: :destroy

  # One type per pedido (Etapa 1.2, 3/3): calçado now; DTF and tecido in Fase 2.
  TIPOS = %w[calcado].freeze
  # The cycle (Etapa 2.2, 3/3; decided 07/10/2026): rascunho → confirmado →
  # em_producao (on its first baixa, by itself) → entregue ("Marcar como
  # entregue"). cancelado: accepted, not used by any screen yet.
  STATUS = %w[rascunho confirmado em_producao entregue cancelado].freeze
  # Takes production baixas; a delivered pedido is read only.
  EM_PRODUCAO = %w[confirmado em_producao].freeze

  belongs_to :entregue_por, class_name: "User", optional: true

  recusa_excluido :client
  validates :status, presence: true, inclusion: { in: STATUS, message: "%{value} is not a pedido status; expected one of #{STATUS.join(", ")}" }
  validates :tipo, inclusion: { in: TIPOS, message: "%{value} is not a pedido type; expected one of #{TIPOS.join(", ")}" }

  scope :rascunhos, -> { where(status: "rascunho") }
  scope :confirmados, -> { where(status: "confirmado") }

  def rotulo_lixeira
    "Pedido #{uuid.first(8)}"
  end

  # A draft that is not in the trash: the only state whose items and pieces
  # can still change.
  # Usage: <% if @pedido.editavel? %> … <% end %>
  # grade_antiga: a pedido from before Etapa 1.2 (3/3), its grade by the
  # corte's size name — read only, even restored from the trash.
  def editavel?
    status == "rascunho" && !excluido? && !grade_antiga?
  end

  # Usage: pedido.em_producao? # => true while confirmado or em_producao
  def em_producao?
    EM_PRODUCAO.include?(status) && !excluido?
  end

  # Past the draft: confirmed, in production or delivered.
  # Usage: pedido.saiu_do_rascunho? # => true
  def saiu_do_rascunho?
    %w[confirmado em_producao entregue].include?(status)
  end

  # The first baixa puts a confirmed pedido in production.
  # Usage: pedido.iniciar_producao!
  def iniciar_producao!
    update!(status: "em_producao") if status == "confirmado"
  end

  # Undoing its last baixa takes it back to confirmed.
  # Usage: pedido.voltar_a_confirmado!
  def voltar_a_confirmado!
    update!(status: "confirmado") if status == "em_producao" && !baixas_producao.vigentes.exists?
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

  # The clients of this pedido's artes (a draft without client is split by
  # them when confirmed). Usage: pedido.clientes_das_artes.map(&:name) # => ["MKS"]
  def clientes_das_artes
    Client.where(id: itens_pedido.joins(:arquivo).select("arquivos.client_id")).order(:name)
  end

  # A draft created for an arte without client (01/10/2026, ed6a2aba) takes
  # the client once every arte of it has the same one.
  # Usage: pedido.adotar_cliente_das_artes!
  def adotar_cliente_das_artes!
    return unless status == "rascunho" && client_id.nil?

    clientes = itens_pedido.joins(:arquivo).distinct.pluck("arquivos.client_id")
    # size, not one?: [mks, nil].one? is true (one? counts truthy values).
    update!(client_id: clientes.first) if clientes.size == 1 && clientes.first
  end
end
