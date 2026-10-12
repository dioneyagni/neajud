class Pedido < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva

  belongs_to :client, optional: true
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :destroy
  has_many :arquivo_vinculo_logs, dependent: :nullify
  # Etapa 2.2 (2/3): what the factory has done, stage by stage.
  has_many :baixas_producao, class_name: "BaixaProducao", dependent: :destroy
  # Etapa 2.8 (5/5): sent, taken back, returned with a note.
  has_many :eventos_pedido, class_name: "EventoPedido", dependent: :destroy

  # One type per pedido (Etapa 1.2, 3/3): calçado now; DTF and tecido in Fase 2.
  TIPOS = %w[calcado].freeze
  # The cycle (Etapa 2.2, 3/3; decided 07/10/2026): rascunho → confirmado →
  # em_producao (on its first baixa, by itself) → entregue ("Marcar como
  # entregue"). cancelado: accepted, not used by any screen yet.
  # enviado (Etapa 2.8, 5/5): a client's draft waiting for the factory, which
  # confirms it or returns it to rascunho with a note.
  STATUS = %w[rascunho enviado confirmado em_producao entregue cancelado].freeze
  # Not confirmed yet: items, parts and grade still follow the artes.
  ANTES_DA_CONFIRMACAO = %w[rascunho enviado].freeze
  # Takes production baixas; a delivered pedido is read only.
  EM_PRODUCAO = %w[confirmado em_producao].freeze

  belongs_to :entregue_por, class_name: "User", optional: true
  # Etapa 2.2 (4/4): a reposição repairs the pieces a Conferência missed.
  belongs_to :reposicao_de, class_name: "Pedido", optional: true
  has_many :reposicoes, class_name: "Pedido", foreign_key: :reposicao_de_id, dependent: :nullify, inverse_of: :reposicao_de
  has_many :itens_reposicao, class_name: "ItemReposicao", dependent: :destroy

  recusa_excluido :client
  validates :status, presence: true, inclusion: { in: STATUS, message: "%{value} is not a pedido status; expected one of #{STATUS.join(", ")}" }
  validates :tipo, inclusion: { in: TIPOS, message: "%{value} is not a pedido type; expected one of #{TIPOS.join(", ")}" }

  scope :rascunhos, -> { where(status: "rascunho") }
  scope :nao_confirmados, -> { where(status: ANTES_DA_CONFIRMACAO) }
  scope :confirmados, -> { where(status: "confirmado") }

  def rotulo_lixeira
    "Pedido #{uuid.first(8)}"
  end

  # A draft that is not in the trash: the only state whose items and pieces
  # can still change. Sent to the factory (Etapa 2.8, 5/5), only the team
  # changes it — the client takes it back first ("Retirar o envio").
  # Usage: <% if @pedido.editavel?(cliente_final: cliente_final?) %> … <% end %>
  # grade_antiga: a pedido from before Etapa 1.2 (3/3), its grade by the
  # corte's size name — read only, even restored from the trash.
  def editavel?(cliente_final: false)
    return false if excluido? || grade_antiga? || reposicao?

    status == "rascunho" || (status == "enviado" && !cliente_final)
  end

  # Not confirmed yet, not in the trash: the factory may still confirm it.
  # Usage: pedido.confirmavel? # => true for a rascunho or an enviado
  def confirmavel?
    ANTES_DA_CONFIRMACAO.include?(status) && !excluido? && !grade_antiga? && !reposicao?
  end

  # The team's note when it returned this draft (Etapa 2.8, 5/5): the latest
  # event, while the client hasn't sent it again.
  # Usage: pedido.devolucao_pendente&.recado # => "Falta a língua 35"
  def devolucao_pendente
    return unless status == "rascunho"

    ultimo = eventos_pedido.order(:id).last
    ultimo if ultimo&.tipo == "devolvido"
  end

  # A sub-pedido of the pieces a Conferência missed (Etapa 2.2, 4/4).
  # Usage: pedido.reposicao? # => true
  def reposicao?
    reposicao_de_id.present?
  end

  # The reposição still gathering this pedido's missing pieces, out of
  # production (Etapa 2.2, 4/4).
  # Usage: pedido.reposicao_em_aberto&.itens_reposicao&.sum(:pecas) # => 3
  def reposicao_em_aberto
    reposicoes.find_by(status: "rascunho")
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

  # Writes each ordered number's price per pair, from its molde, into the
  # grade (Etapa 2.4, decided 09/10/2026): a later change of the molde's
  # price only reaches drafts. Called when the pedido is confirmed.
  # Usage: pedido.gravar_precos!
  def gravar_precos!
    itens_pedido.includes(:grades, arquivo: :molde).find_each do |item|
      molde = item.arquivo&.molde
      item.grades.select { |g| g.quantidade.positive? }.each { |g| g.update!(preco_par: molde&.preco_do_par(g.tamanho_nome)) }
    end
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
    return unless ANTES_DA_CONFIRMACAO.include?(status) && client_id.nil?

    clientes = itens_pedido.joins(:arquivo).distinct.pluck("arquivos.client_id")
    # size, not one?: [mks, nil].one? is true (one? counts truthy values).
    update!(client_id: clientes.first) if clientes.size == 1 && clientes.first
  end
end
