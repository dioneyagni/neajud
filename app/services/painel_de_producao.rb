# The Painel's rows by block (Painel 1/4, decided 04/11/2026): every pedido
# not delivered — and, asked for, the ones delivered in the last 7 days —,
# one LinhaDoPainel each. Blocks follow the status until the turnos and the
# programação (2/4, 3/4) bring Agora / Próximos / Amanhã:
#
#   :em_andamento — some stage already took a baixa
#   :prontos      — confirmed, nothing holds it, no baixa yet
#   :pendentes    — a draft, sent, or waiting for material
#   :entregues    — delivered (only with entregues: true)
#
# Inside a block, the most urgent first (Q7): past the deadline, with a
# pendência, the nearest deadline, the arrival order. The baixas of every
# pedido come in one query (measured 04/11/2026: per stage they made the
# page slow).
#
# Usage: painel = PainelDeProducao.call(visiveis(Pedido))
#        painel.blocos.map { |b| [ b.chave, b.linhas.size ] } # => [[:em_andamento, 2], [:prontos, 8], …]
class PainelDeProducao
  BLOCOS = { em_andamento: "Em andamento", prontos: "Prontos para começar", pendentes: "Pendentes de início", entregues: "Entregues (7 dias)" }.freeze
  ABERTOS = %w[rascunho enviado confirmado em_producao].freeze
  DIAS_DOS_ENTREGUES = 7
  # A pedido without deadline sorts after every dated one.
  SEM_PRAZO = Date.new(9999, 12, 31)

  Bloco = Struct.new(:chave, :nome, :linhas, keyword_init: true)
  Painel = Struct.new(:blocos, :colunas, keyword_init: true) do
    def linhas
      blocos.flat_map(&:linhas)
    end
  end

  # pedidos: the scope this person sees (visiveis(Pedido)).
  def self.call(pedidos, entregues: false, cliente_final: false, hoje: Date.current)
    new(pedidos, entregues, cliente_final, hoje).call
  end

  # One pedido's row, for the live update; nil when it is not on the Painel.
  # Usage: PainelDeProducao.linha(visiveis(Pedido), uuid)&.bloco # => :prontos
  def self.linha(pedidos, uuid, cliente_final: false)
    pedido = do_painel(pedidos, true).find_by(uuid: uuid)
    pedido && LinhaDoPainel.call(pedido, aguardando: AguardandoMaterial.call, cliente_final: cliente_final)
  end

  # The pedidos the Painel shows, out of the visible ones.
  def self.do_painel(pedidos, entregues)
    # A reposição still gathering pieces (rascunho) is not a pedido to produce yet.
    abertos = pedidos.ativos.where(status: ABERTOS).where("pedidos.status <> 'rascunho' OR pedidos.reposicao_de_id IS NULL")
    abertos = abertos.or(pedidos.ativos.where(status: "entregue", entregue_em: DIAS_DOS_ENTREGUES.days.ago..)) if entregues
    abertos.includes(:client, itens_pedido: :arte)
  end

  def initialize(pedidos, entregues, cliente_final, hoje)
    @pedidos = self.class.do_painel(pedidos, entregues).to_a
    @entregues = entregues
    @cliente_final = cliente_final
    @hoje = hoje
  end

  def call
    linhas = montar_linhas
    blocos = BLOCOS.filter_map do |chave, nome|
      Bloco.new(chave: chave, nome: nome, linhas: ordenar(linhas.select { |l| l.bloco == chave })) unless chave == :entregues && !@entregues
    end
    Painel.new(blocos: blocos, colunas: colunas_usadas(linhas))
  end

  private

  def montar_linhas
    aguardando = AguardandoMaterial.call
    baixas = BaixaProducao.vigentes.where(pedido_id: @pedidos.map(&:id)).includes(:user).group_by(&:pedido_id)
    @pedidos.map { |p| LinhaDoPainel.call(p, aguardando: aguardando, baixas: baixas.fetch(p.id, []), cliente_final: @cliente_final) }
  end

  def ordenar(linhas)
    linhas.sort_by { |l| [ l.atrasado?(@hoje) ? 0 : 1, l.pendencia? ? 0 : 1, l.pedido.prazo_entrega || SEM_PRAZO, l.chegada ] }
  end

  # Empty columns hide (Q4): a column shows when some row goes through it.
  def colunas_usadas(linhas)
    LinhaDoPainel::COLUNAS.select { |chave, _| linhas.any? { |l| l.celulas[chave].estado != :nao_tem } }
  end
end
