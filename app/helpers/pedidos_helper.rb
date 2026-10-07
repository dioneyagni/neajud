# The pedido page's matrix (Etapa 1.2, 3/3 parte 3a, decided 06/10/2026):
# one column per number of the arte's grade, rows "Pares" and one per part.
module PedidosHelper
  Colunas = Struct.new(:ordem, :visiveis, keyword_init: true)

  # Every number the item may take, in the product's order, and the ones shown
  # at first: the molde's DXF numbers plus any already ordered. The others stay
  # hidden behind "+ 28" / "+ 32". An arte without molde has one column, the
  # total.
  # Usage: colunas_do_item(item) # => #<Colunas ordem=["18", …, "46"] visiveis=["29", "30", "31"]>
  def colunas_do_item(item)
    listados = tamanhos_for_arte(item.arquivo).map { |t| t[:nome] }
    pedidos = item.grades.select { |g| g.quantidade.positive? }.map(&:tamanho_nome)
    return Colunas.new(ordem: [ ProducaoPedidoService::TOTAL_KEY ], visiveis: [ ProducaoPedidoService::TOTAL_KEY ]) if listados.empty?

    completa = grade_completa_for_arte(item.arquivo).presence || listados
    ordem = completa + (pedidos - completa)
    Colunas.new(ordem: ordem, visiveis: ordem.select { |n| listados.include?(n) || pedidos.include?(n) })
  end

  # Usage: rotulo_do_numero("_total") # => "Qtd"
  def rotulo_do_numero(numero)
    numero == ProducaoPedidoService::TOTAL_KEY ? "Qtd" : numero
  end

  # The cell's state, also its CSS modifier: a pendência (sem_corte,
  # sem_arquivo, sem_lado), where the file comes from (producao, piloto), or — a number
  # not ordered — whether a DXF size serves it (livre) or not (vazio).
  # Usage: estado_da_celula(parte.celula("30")) # => :sem_arquivo
  def estado_da_celula(numero)
    return numero.pendencia || numero.origem if numero.quantidade.positive?

    numero.tamanho ? :livre : :vazio
  end

  # The Impressão page's file column: the file's name, or what is missing.
  # Usage: arquivo_da_linha_de_impressao(linha) # => "sem o arquivo DIR"
  def arquivo_da_linha_de_impressao(linha)
    case linha.pendencia
    when :sem_lado then "sem o arquivo #{LadoNaArte::ABREVIACOES[linha.lado]}"
    when :sem_arquivo then "sem arquivo de produção"
    when :sem_corte then "nenhum corte organizado atende"
    else "#{linha.arquivo.filename}.#{linha.arquivo.extension}"
    end
  end
end
