# What a tecido pedido charges (Etapa 2.7b, decided 17/10/2026): per item,
# its meters × the print per meter and, when the fabric is the empresa's,
# × the fabric per meter (PrecosDoItemTecido). Each keeps its starting price
# beside, so the discount is measured; a missing price is a falta (the
# pendência :sem_preco_tecido). Confirming writes them (gravar!).
#
# Usage: valores = ValoresDoPedidoTecido.call(pedido)
#        valores.do_item(item).subtotal # => 270.0; valores.total # => 540.0
class ValoresDoPedidoTecido
  Cobranca = ValoresDoPedidoDtf::Cobranca

  # One item's charges: the print, and the fabric (nil when the client's).
  Item = Struct.new(:item, :impressao, :tecido, keyword_init: true) do
    def cobrancas
      [ impressao, tecido ].compact
    end

    def subtotal
      cobrancas.filter_map(&:subtotal).sum
    end

    # What the client pays per meter, print and fabric together.
    def preco_por_metro
      cobrancas.filter_map(&:preco).sum
    end
  end

  Valores = Struct.new(:itens, keyword_init: true) do
    def do_item(item)
      itens.find { |valor| valor.item.id == item.id }
    end

    def cobrancas
      itens.flat_map(&:cobrancas)
    end

    # Each kind summed, the rows of "Valores do pedido".
    def impressao = somar(itens.map(&:impressao))
    def tecido = itens.any?(&:tecido) ? somar(itens.filter_map(&:tecido)) : nil

    def total
      cobrancas.filter_map(&:subtotal).sum
    end

    def desconto
      cobrancas.select(&:preco).sum { |parte| (parte.subtotal_partida || parte.subtotal) - parte.subtotal }
    end

    def faltas
      cobrancas.reject(&:preco)
    end

    private

    def somar(partes)
      ValoresDoPedidoDtf::Soma.new(quantidade: partes.sum(&:quantidade), subtotal: partes.filter_map(&:subtotal).sum,
                                   subtotal_partida: partes.sum { |parte| parte.subtotal_partida || parte.subtotal || 0 })
    end
  end

  def self.call(pedido)
    itens = pedido.itens_pedido.includes(:arte, :materia_prima).order(:id).map { |item| do_item(item) }
    Valores.new(itens: itens)
  end

  # Usage: ValoresDoPedidoTecido.gravar!(pedido)
  def self.gravar!(pedido)
    pedido.itens_pedido.each(&:confirmar_precos_tecido!)
  end

  def self.do_item(item)
    metros = item.metros.to_d
    impressao = Cobranca.new(descricao: "Impressão", linha: item, quantidade: metros,
                             preco_partida: item.preco_impressao_de_partida, preco: item.preco_impressao_efetivo)
    tecido = item.cobra_tecido? ? Cobranca.new(descricao: "Tecido", linha: item, quantidade: metros,
                                               preco_partida: item.preco_tecido_de_partida, preco: item.preco_tecido_efetivo) : nil
    Item.new(item: item, impressao: impressao, tecido: tecido)
  end
  private_class_method :do_item
end
