# The Painel's rows by block (Painel 1/4, decided 04/11/2026): every pedido
# not delivered — and, asked for, the ones delivered in the last 7 days —,
# one LinhaDoPainel each. Painel 2/4b: the blocks are in time, where each
# row's next piece of work is in the queue (BlocosNoTempo, FilaDeProducao),
# and every row has its previsão. The baixas of every pedido come in one
# query, their stages' states read once for the rows and the queue
# (measured 04/11/2026: per stage they made the page slow).
#
# A reposição (decided 05/11/2026) is a row under its original, in the
# original's block and order, while the original is not delivered; its
# original or delivered, it is a row of its own. One still gathering pieces
# (rascunho) is not a row: the original says how many it holds.
#
# Usage: painel = PainelDeProducao.call(visiveis(Pedido))
#        painel.blocos.map { |b| [ b.chave, b.linhas.size ] } # => [["agora", 2], ["amanha", 8], …]
#        painel.fila.do_setor("corte")
class PainelDeProducao
  ABERTOS = %w[rascunho enviado confirmado em_producao].freeze
  DIAS_DOS_ENTREGUES = 7

  Painel = Struct.new(:blocos, :colunas, :fila, keyword_init: true) do
    def linhas
      blocos.flat_map(&:linhas)
    end
  end

  # pedidos: the scope this person sees (visiveis(Pedido)). The queue reads
  # the whole factory, its calendar too (FilaDeProducao).
  def self.call(pedidos, entregues: false, cliente_final: false, agora: Time.current, calendario: CalendarioDeProducao.new)
    new(pedidos, entregues, cliente_final, agora, calendario).call
  end

  # The pedidos the Painel shows, out of the visible ones.
  def self.do_painel(pedidos, entregues)
    # A reposição still gathering pieces (rascunho) is not a pedido to produce yet.
    abertos = pedidos.ativos.where(status: ABERTOS).where("pedidos.status <> 'rascunho' OR pedidos.reposicao_de_id IS NULL")
    abertos = abertos.or(pedidos.ativos.where(status: "entregue", entregue_em: DIAS_DOS_ENTREGUES.days.ago..)) if entregues
    abertos.includes(:client, :reposicao_de, :itens_reposicao, itens_pedido: :arte)
  end

  def initialize(pedidos, entregues, cliente_final, agora, calendario)
    @visiveis = pedidos
    @pedidos = self.class.do_painel(pedidos, entregues).to_a
    @entregues = entregues
    @cliente_final = cliente_final
    @agora = agora
    @calendario = calendario
  end

  def call
    linhas = montar_linhas
    blocos = BlocosNoTempo.call(linhas, agora: @agora, cliente_final: @cliente_final, entregues: @entregues)
    Painel.new(blocos: blocos, colunas: colunas_usadas(linhas), fila: @fila)
  end

  private

  # The top rows, each with its reposições inside (built first: the
  # original's Entrega waits for them).
  def montar_linhas
    @aguardando = AguardandoMaterial.call
    @estados = estados_das_etapas
    @fila = FilaDeProducao.call(agora: @agora, calendario: @calendario, estados: @estados, aguardando: @aguardando)
    @juntando = pecas_juntando
    @filhas = @pedidos.select { |p| aninhada?(p) }.group_by(&:reposicao_de_id)
    @pedidos.reject { |p| aninhada?(p) }.map { |p| linha_com_reposicoes(p) }
  end

  # Every pedido past the draft, its baixas in one query.
  def estados_das_etapas
    producao = @pedidos.select(&:saiu_do_rascunho?)
    baixas = BaixaProducao.vigentes.where(pedido_id: producao.map(&:id)).includes(:user).group_by(&:pedido_id)
    producao.to_h { |pedido| [ pedido.id, EstadoDasEtapas.call(pedido, baixas: baixas.fetch(pedido.id, [])) ] }
  end

  def linha_com_reposicoes(pedido)
    LinhaDoPainel.call(pedido, aguardando: @aguardando, estados: @estados[pedido.id], fila: @fila, cliente_final: @cliente_final,
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

  # Empty columns hide (Q4): a column shows when some row goes through it.
  def colunas_usadas(linhas)
    todas = linhas.flat_map(&:com_reposicoes)
    LinhaDoPainel::COLUNAS.select { |chave, _| todas.any? { |l| l.celulas[chave].estado != :nao_tem } }
  end
end
