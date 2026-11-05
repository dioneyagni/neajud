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
# A reposição (decided 05/11/2026) is a row under its original, in the
# original's block and order, while the original is not delivered; its
# original or delivered, it is a row of its own. One still gathering pieces
# (rascunho) is not a row: the original says how many it holds.
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

  # One pedido's row, for the live update — a reposição under its original
  # comes back as the original's row, with it inside; nil when it is not on
  # the Painel.
  # Usage: PainelDeProducao.linha(visiveis(Pedido), uuid)&.bloco # => :prontos
  def self.linha(pedidos, uuid, cliente_final: false)
    pedido = pedidos.ativos.find_by(uuid: uuid)
    return unless pedido

    raiz = raiz_de(pedidos, pedido)
    new(familia(pedidos, raiz), true, cliente_final, Date.current).call.linhas.find { |linha| linha.pedido.id == raiz.id }
  end

  # The pedido and its reposições, theirs too (a reposição can miss pieces).
  def self.familia(pedidos, raiz)
    ids = nivel = [ raiz.id ]
    ids += nivel while (nivel = pedidos.where(reposicao_de_id: nivel).ids).any?
    pedidos.where(id: ids)
  end
  private_class_method :familia

  # The row a pedido is shown in: a reposição's original while it is open.
  def self.raiz_de(pedidos, pedido)
    original = pedido.reposicao_de_id && pedidos.ativos.where.not(status: "entregue").find_by(id: pedido.reposicao_de_id)
    original ? raiz_de(pedidos, original) : pedido
  end
  private_class_method :raiz_de

  # The pedidos the Painel shows, out of the visible ones.
  def self.do_painel(pedidos, entregues)
    # A reposição still gathering pieces (rascunho) is not a pedido to produce yet.
    abertos = pedidos.ativos.where(status: ABERTOS).where("pedidos.status <> 'rascunho' OR pedidos.reposicao_de_id IS NULL")
    abertos = abertos.or(pedidos.ativos.where(status: "entregue", entregue_em: DIAS_DOS_ENTREGUES.days.ago..)) if entregues
    abertos.includes(:client, :reposicao_de, :itens_reposicao, itens_pedido: :arte)
  end

  def initialize(pedidos, entregues, cliente_final, hoje)
    @visiveis = pedidos
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

  # The top rows, each with its reposições inside (built first: the
  # original's Entrega waits for them).
  def montar_linhas
    @aguardando = AguardandoMaterial.call
    @baixas = BaixaProducao.vigentes.where(pedido_id: @pedidos.map(&:id)).includes(:user).group_by(&:pedido_id)
    @juntando = pecas_juntando
    @filhas = @pedidos.select { |p| aninhada?(p) }.group_by(&:reposicao_de_id)
    @pedidos.reject { |p| aninhada?(p) }.map { |p| linha_com_reposicoes(p) }
  end

  def linha_com_reposicoes(pedido)
    LinhaDoPainel.call(pedido, aguardando: @aguardando, baixas: @baixas.fetch(pedido.id, []), cliente_final: @cliente_final,
                               reposicoes: @filhas.fetch(pedido.id, []).map { |filha| linha_com_reposicoes(filha) }, juntando: @juntando[pedido.id])
  end

  # Under its original: the original is on the Painel and not delivered.
  def aninhada?(pedido)
    @originais ||= @pedidos.index_by(&:id)
    original = @originais[pedido.reposicao_de_id]
    pedido.status != "entregue" && original.present? && original.status != "entregue"
  end

  # The pieces each original's reposição still gathering holds.
  def pecas_juntando
    juntando = @visiveis.ativos.where(status: "rascunho", reposicao_de_id: @pedidos.map(&:id)).includes(:itens_reposicao)
    juntando.to_h { |reposicao| [ reposicao.reposicao_de_id, reposicao.itens_reposicao.sum(&:pecas) ] }
  end

  def ordenar(linhas)
    linhas.sort_by { |l| [ l.atrasado?(@hoje) ? 0 : 1, l.pendencia? ? 0 : 1, l.prazo || SEM_PRAZO, l.chegada ] }
  end

  # Empty columns hide (Q4): a column shows when some row goes through it.
  def colunas_usadas(linhas)
    todas = linhas.flat_map(&:com_reposicoes)
    LinhaDoPainel::COLUNAS.select { |chave, _| todas.any? { |l| l.celulas[chave].estado != :nao_tem } }
  end
end
