# What a pedido sends to production: one line per peça with the quantity per
# tamanho, summed over every item whose piece is checked and has an arte.
# Unchecked pieces are left out (the pedido goes to production without them);
# pending pieces (no arte) cannot be produced and block confirming instead.
# This is the single place production reads from — see Pedido#pecas_para_produzir.
#
# Usage: ProducaoPedidoService.call(pedido)
#   # => [#<Linha peca=Lateral cortes=[<corte>] quantidades={"35"=>10, "36"=>4}>]
class ProducaoPedidoService
  # Grade key used when an item has no tamanhos (a single total quantity).
  TOTAL_KEY = "_total".freeze

  Linha = Struct.new(:peca, :cortes, :quantidades, keyword_init: true) do
    def total
      quantidades.values.sum
    end
  end

  def self.call(pedido)
    new(pedido).call
  end

  # Numeric sizes first by value ("9" before "10"), then others by name,
  # the single-total column last.
  # Usage: ProducaoPedidoService.ordenar_tamanhos(%w[36 _total 4 P]) # => ["4", "36", "P", "_total"]
  def self.ordenar_tamanhos(nomes)
    nomes.uniq.sort_by do |nome|
      next [ 2, 0, "" ] if nome == TOTAL_KEY

      nome.match?(/\A\d+(\.\d+)?\z/) ? [ 0, nome.to_f, nome ] : [ 1, 0, nome ]
    end
  end

  def initialize(pedido)
    @pedido = pedido
  end

  def call
    linhas = {}
    pecas_para_producao.each { |peca_row| somar(linhas, peca_row) }
    linhas.values.sort_by { |linha| [ linha.peca ? 0 : 1, linha.peca&.nome.to_s ] }
  end

  private

  def pecas_para_producao
    ItemPedidoPeca.para_producao
                  .joins(:item_pedido).where(itens_pedido: { pedido_id: @pedido.id })
                  .includes(:peca, arquivo: { tamanho: :arquivo }, item_pedido: :grades)
  end

  def somar(linhas, peca_row)
    linha = linhas[peca_row.peca_id] ||= Linha.new(peca: peca_row.peca, cortes: [], quantidades: Hash.new(0))
    corte = peca_row.arquivo.corte
    linha.cortes << corte if corte && !linha.cortes.include?(corte)
    peca_row.item_pedido.grades.each { |grade| linha.quantidades[grade.tamanho_nome] += grade.quantidade }
  end
end
