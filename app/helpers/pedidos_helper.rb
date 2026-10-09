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

  # The expected metragem of a production line (Etapa 2.2, 1/3), or why there
  # is none yet.
  # Usage: metragem_esperada(0.37, "tecido") # => "≈ 0,37 m de tecido"
  def metragem_esperada(metros, material, falta: "metragem ainda não calculada")
    return falta unless metros

    "≈ #{number_with_precision(metros, precision: 2, separator: ",")} m de #{material}"
  end

  # Why a Corte line has no expected metragem yet (Etapa 2.2, 1/3).
  # Usage: falta_de_metragem_do_corte(linha) # => "giro do corte não marcado"
  def falta_de_metragem_do_corte(linha)
    return "sem material: sem metragem" unless linha.materia_prima
    return "giro do corte não marcado" if linha.corte && linha.corte.giro.nil?

    "metragem ainda não calculada"
  end

  # May this user give production baixas on this pedido (Etapa 2.2, 2/3)?
  # A confirmed pedido, not in the trash, and the atualizar_producao action.
  # Usage: <% if pode_dar_baixa?(@pedido) %> … <% end %>
  def pode_dar_baixa?(pedido)
    pode_acao?(:atualizar_producao) && pedido.em_producao?
  end

  # A stage's progress: "3 de 5 linhas" (Etapa 2.2, 2/3).
  # Usage: andamento_da_etapa(situacoes) # => "3 de 5 linhas feitas"
  def andamento_da_etapa(situacoes)
    feitas = situacoes.values.count { |s| s.estado == :feita }
    "#{feitas} de #{situacoes.size} #{situacoes.size == 1 ? "linha feita" : "linhas feitas"}"
  end

  # A production stage's page: Impressão and Corte have their own, the others
  # share the stage page (Etapa 2.2, 2/3).
  # Usage: caminho_da_etapa(pedido, etapa) # => "/pedidos/…/etapas/estamparia"
  def caminho_da_etapa(pedido, etapa)
    case etapa.chave
    when "impressao" then impressao_pedido_path(pedido)
    when "corte" then corte_pedido_path(pedido)
    else etapa_pedido_path(pedido, etapa: etapa.chave)
    end
  end

  ROTULOS_DE_STATUS = { "rascunho" => "rascunho", "confirmado" => "confirmado", "em_producao" => "em produção",
                        "entregue" => "entregue", "cancelado" => "cancelado" }.freeze

  # The pedido's status as people say it (Etapa 2.2, 3/3); a reposição
  # still gathering pieces is "em aberto" (4/4).
  # Usage: rotulo_do_status("em_producao") # => "em produção"
  #        rotulo_do_status(reposicao.status, reposicao: true) # => "em aberto"
  def rotulo_do_status(status, reposicao: false)
    return "em aberto" if reposicao && status == "rascunho"

    ROTULOS_DE_STATUS.fetch(status, status)
  end

  # How a Corte line's pieces add up: right / left, pairs × pieces per pair,
  # or a reposição's pieces (Etapa 2.2, 4/4).
  # Usage: conta_da_linha_do_corte(linha) # => "10 pares × 2"
  def conta_da_linha_do_corte(linha)
    return "peças de reposição" if linha.pecas_fixas
    return "#{linha.por_lado} direito · #{linha.por_lado} esquerdo" if linha.espelhada

    "#{linha.pares} #{linha.pares == 1 ? "par" : "pares"} × #{linha.pecas_por_par}"
  end
end
