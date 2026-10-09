# The pedido's price, cost and margin (Etapa 2.4, decided 09/10/2026), per
# item and number, for whoever has the "ver_valores" action. Calçado is
# charged per pair: the price written when the pedido was confirmed
# (ItemPedidoGrade#preco_par), else — in a draft — the molde's price now.
# The cost per pair is an estimate, always computed now (CustoPorPar); nil
# while the dono hasn't set the costs in Parâmetros.
#
# Usage: valores = ValoresDoPedido.call(pedido, empresa: Empresa.atual)
#        valores.valor # => 1180.0
#        valores.itens.first.linhas.first.margem_par # => 6.63
class ValoresDoPedido
  Linha = Struct.new(:numero, :pares, :preco_par, :custo, keyword_init: true) do
    def custo_par
      custo&.total
    end

    def margem_par
      preco_par && custo_par && preco_par - custo_par
    end
  end

  Item = Struct.new(:item, :linhas, keyword_init: true)

  attr_reader :itens

  def self.call(pedido, empresa:)
    new(pedido, empresa)
  end

  def initialize(pedido, empresa)
    @empresa = empresa
    @itens = pedido.itens_pedido.includes(:grades, :arte, :arquivo, item_pedido_pecas: :peca).order(:id).map { |item| item_com_linhas(item) }
  end

  # Usage: valores.valor # => 1180.0 (numbers without price left out — see sem_preco?)
  def valor
    linhas.sum { |l| l.preco_par ? l.preco_par * l.pares : 0 }
  end

  def custo
    linhas.sum { |l| l.custo_par ? l.custo_par * l.pares : 0 }
  end

  def margem
    valor - custo
  end

  def sem_preco?
    linhas.any? { |l| l.preco_par.nil? }
  end

  def custo_incompleto?
    !@empresa.custos_definidos? || linhas.any? { |l| l.custo.nil? || l.custo.incompleto }
  end

  private

  def linhas
    @itens.flat_map(&:linhas)
  end

  def item_com_linhas(item)
    custos = @empresa.custos_definidos? ? CustoPorPar.call(item, empresa: @empresa) : {}
    molde = item.arquivo&.molde
    grades = item.grades.select { |g| g.quantidade.positive? }.sort_by { |g| [ g.tamanho_nome.to_i, g.tamanho_nome ] }
    Item.new(item: item, linhas: grades.map do |grade|
      Linha.new(numero: grade.tamanho_nome, pares: grade.quantidade, preco_par: grade.preco_par || molde&.preco_do_par(grade.tamanho_nome),
                custo: custos[grade.tamanho_nome])
    end)
  end
end
