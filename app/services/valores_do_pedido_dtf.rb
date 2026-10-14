# What a DTF pedido charges (Etapa 2.6c, decided 13-14/10/2026), on its fit
# (EncaixeDoPedidoDtf):
# - by quantity: each line's units — the ordered ones, or the printed when
#   the excess is charged — × its unit price: edited in the pedido, else the
#   etiqueta's agreed, else calculated with the ordering client's own price
#   per meter, else the etiqueta's calculated one (D1, D3, D4, D6);
# - by meter: the whole pedido's meters (the excess always in) × the price
#   per meter;
# - cortada: every printed unit is cut, × the price per unit cut (D5).
# Each price keeps its starting one beside, so the discount is measured.
# Confirming writes them (gravar!); a confirmed pedido reads what was written.
#
# Usage: valores = ValoresDoPedidoDtf.call(pedido)
#        valores.total # => 37.2; valores.desconto # => 2.4; valores.faltas # => []
class ValoresDoPedidoDtf
  # A charged amount: the line's units (or meters) × its price.
  Cobranca = Struct.new(:descricao, :linha, :quantidade, :preco_partida, :preco, keyword_init: true) do
    def subtotal
      preco && (quantidade * preco).round(2)
    end

    def subtotal_partida
      preco_partida && (quantidade * preco_partida).round(2)
    end
  end

  Valores = Struct.new(:cobranca, :cobra_excedente, :partes, keyword_init: true) do
    def total
      partes.filter_map(&:subtotal).sum
    end

    def desconto
      partes.select(&:preco).sum { |parte| (parte.subtotal_partida || parte.subtotal) - parte.subtotal }
    end

    # What has no price (a pendência: the pedido can't be confirmed).
    def faltas
      partes.reject(&:preco)
    end
  end

  def self.call(pedido)
    new(pedido).call
  end

  # Writes each line's starting and charged unit price, and the pedido's
  # choices and prices (confirming).
  # Usage: ValoresDoPedidoDtf.gravar!(pedido)
  def self.gravar!(pedido)
    call(pedido).partes.select(&:linha).each do |parte|
      parte.linha.grade.update!(preco_unidade_partida: parte.preco_partida, preco_unidade: parte.preco)
    end
    pedido.confirmar_cobranca!
  end

  def initialize(pedido)
    @pedido = pedido
    @confirmado = Pedido::ANTES_DA_CONFIRMACAO.exclude?(pedido.status)
  end

  def call
    linhas = EncaixeDoPedidoDtf.call(@pedido).reject(&:pendencia)
    partes = @pedido.cobranca_efetiva == "metro" ? [ por_metro(linhas) ] : linhas.map { |linha| por_unidade(linha) }
    partes << do_corte(linhas) if @pedido.entrega == "cortada"
    Valores.new(cobranca: @pedido.cobranca_efetiva, cobra_excedente: @pedido.cobra_excedente?, partes: partes)
  end

  private

  def por_unidade(linha)
    grade = linha.grade
    partida = @confirmado ? grade.preco_unidade_partida : partida_da_linha(linha)
    unidades = @pedido.cobra_excedente? ? linha.impressas : linha.pedidas
    Cobranca.new(descricao: "#{linha.item.arte.titulo} #{rotulo(grade.tamanho_nome)}".strip, linha: linha, quantidade: unidades,
                 preco_partida: partida, preco: @confirmado ? grade.preco_unidade : grade.preco_unidade || partida)
  end

  # The cascade below the pedido's own edit.
  def partida_da_linha(linha)
    arquivo = linha.arquivo
    return arquivo.preco_unidade_combinado if arquivo.preco_unidade_combinado

    proprio = @pedido.client&.preco_metro_dtf
    proprio ? PrecoDaEtiqueta.unitario(arquivo.encaixe_dtf, proprio) : arquivo.preco_unidade_calculado
  end

  def por_metro(linhas)
    Cobranca.new(descricao: "Filme", quantidade: linhas.sum(&:metros).round(4),
                 preco_partida: @pedido.preco_metro_de_partida, preco: @pedido.preco_metro_efetivo)
  end

  def do_corte(linhas)
    Cobranca.new(descricao: "Corte", quantidade: linhas.sum(&:impressas),
                 preco_partida: @pedido.preco_corte_de_partida, preco: @pedido.preco_corte_efetivo)
  end

  def rotulo(tamanho_nome)
    tamanho_nome == ProducaoPedidoService::TOTAL_KEY ? "" : tamanho_nome
  end
end
