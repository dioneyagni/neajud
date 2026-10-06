# What a pedido sends to production: one line per peça + corte with the
# quantity per tamanho, summed over every item whose piece is checked and has
# an arte. Lines are per corte (not just per peça) because the factory
# downloads each size's DXF from a specific corte; two cortes for the same
# peça would otherwise mix their quantities.
# Unchecked pieces are left out (the pedido goes to production without them);
# pending pieces (no arte) cannot be produced and block confirming instead.
# This is the single place production reads from — see Pedido#pecas_para_produzir.
#
# Usage: ProducaoPedidoService.call(pedido)
#   # => [#<Linha peca=Lateral corte=<corte> quantidades={"35"=>10} downloads={"35"=>[<Tamanho 35>]}>]
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
    pecas_para_producao.each { |peca_row| somar(linhas, peca_row) }
    linhas.values.sort_by { |linha| [ linha.peca ? 0 : 1, linha.peca&.nome.to_s, linha.corte&.filename.to_s ] }
  end

  private

  def pecas_para_producao
    ItemPedidoPeca.para_producao
                  .joins(:item_pedido).where(itens_pedido: { pedido_id: @pedido.id })
                  .includes(:peca, arquivo: { tamanho: { arquivo: :tamanhos } }, item_pedido: :grades)
  end

  def somar(linhas, peca_row)
    corte = peca_row.arquivo.corte
    linha = linhas[[ peca_row.peca_id, corte&.id ]] ||=
      Linha.new(peca: peca_row.peca, corte: corte, quantidades: Hash.new(0), downloads: Hash.new { |h, k| h[k] = [] })
    peca_row.item_pedido.grades.each do |grade|
      linha.quantidades[grade.tamanho_nome] += grade.quantidade
      registrar_download(linha, grade.tamanho_nome, peca_row.arquivo)
    end
  end

  # A size maps to the corte's tamanho that serves it; the single-total
  # column (no sizes in the grade) uses the size chosen on the arte itself.
  def registrar_download(linha, tamanho_nome, arte)
    return unless linha.corte

    # Etapa 1.2 (3/3): the grade is by number; the corte's size serving it ("29" → 29-30).
    tamanho = tamanho_nome == TOTAL_KEY ? arte.tamanho : linha.corte.tamanhos.find { |t| t.atende_rotulo?(tamanho_nome) }
    lista = linha.downloads[tamanho_nome]
    lista << tamanho if tamanho && !lista.include?(tamanho)
  end
end
