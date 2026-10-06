# What a pedido sends to production: one line per peça + corte with the
# quantity per ordered number, summed over every item whose part is checked
# (Etapa 1.2, 3/3: read from ResolucaoDoItem — the number's DXF size in the
# part). Lines are per corte (not just per peça) because the factory
# downloads each size's DXF from a specific corte; two cortes for the same
# peça would otherwise mix their quantities. A number no DXF serves stays in a
# line without corte (it also blocks confirming). Unchecked parts are left out.
# This is the single place production reads from — see Pedido#pecas_para_produzir.
#
# Usage: ProducaoPedidoService.call(pedido)
#   # => [#<Linha peca=Lateral corte=<corte> quantidades={"29"=>4, "30"=>6} downloads={"29"=>[<Tamanho 29-30>], …}>]
class ProducaoPedidoService
  # Grade key used when an item has no tamanhos (a single total quantity).
  TOTAL_KEY = "_total".freeze

  # downloads: tamanho name → the corte's Tamanho records to download for it
  # (empty = the corte has no such size: no DXF, blocks confirming).
  Linha = Struct.new(:peca, :corte, :quantidades, :downloads, keyword_init: true) do
    def total
      quantidades.values.sum
    end

    # Usage: linha.tamanhos_faltando # => ["35"]
    def tamanhos_faltando
      return [] unless corte

      quantidades.select { |_, qtd| qtd.positive? }.keys.select { |nome| downloads[nome].empty? }
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
    @pedido.itens_pedido.includes(:grades, :arte, :arquivo, item_pedido_pecas: :peca).order(:id).each do |item|
      ResolucaoDoItem.call(item).select(&:incluida).each { |parte| somar(linhas, parte) }
    end
    linhas.values.sort_by { |linha| [ linha.peca ? 0 : 1, linha.peca&.nome.to_s, linha.corte&.filename.to_s ] }
  end

  private

  # Etapa 1.2 (3/3, parte 2): read from ResolucaoDoItem — each number goes to
  # the DXF size that serves it in its part ("29" → 29-30).
  def somar(linhas, parte)
    parte.numeros.each do |numero|
      corte = numero.tamanho&.arquivo
      linha = linhas[[ parte.peca&.id, corte&.id ]] ||=
        Linha.new(peca: parte.peca, corte: corte, quantidades: Hash.new(0), downloads: Hash.new { |h, k| h[k] = [] })
      linha.quantidades[numero.numero] += numero.quantidade
      lista = linha.downloads[numero.numero]
      lista << numero.tamanho if numero.tamanho && !lista.include?(numero.tamanho)
    end
  end
end
