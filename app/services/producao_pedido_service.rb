# What a pedido sends to the cutting table (Etapa 1.2, 3/3 parte 3b, decided
# 06/10/2026): one line per part × DXF size, with the ordered numbers it
# serves summed over every item whose part is checked, and the pieces to cut
# — pairs × the molde part's pecas_por_par, half right and half left when
# espelhada. Read from ResolucaoDoItem (the number's DXF size in the part).
# Parts marked "não corta" on the molde are left out (decided 06/10/2026:
# they never reach the table; they are printed only). Numbers no DXF serves
# stay in a line without size (they also block confirming).
# This is the single place production reads from — see Pedido#pecas_para_produzir.
#
# Usage: ProducaoPedidoService.call(pedido)
#   # => [#<Linha peca=Lateral tamanho=<29-30> quantidades={"29"=>4, "30"=>6} pecas_por_par=2 espelhada=true>]
class ProducaoPedidoService
  # Grade key used when an item has no tamanhos (a single total quantity).
  TOTAL_KEY = "_total".freeze

  Linha = Struct.new(:peca, :tamanho, :quantidades, :pecas_por_par, :espelhada, keyword_init: true) do
    def corte
      tamanho&.arquivo
    end

    def pares
      quantidades.values.sum
    end

    # Usage: linha.pecas # => 20 (10 pairs × 2)
    def pecas
      pares * pecas_por_par
    end

    # Pieces of each side of a mirrored part (nil when not mirrored).
    # Usage: linha.por_lado # => 10
    def por_lado
      espelhada ? pecas / 2 : nil
    end
  end

  def self.call(pedido)
    new(pedido).call
  end

  def initialize(pedido)
    @pedido = pedido
  end

  def call
    linhas = {}
    @pedido.itens_pedido.includes(:grades, :arte, :arquivo, item_pedido_pecas: :peca).order(:id).each do |item|
      ResolucaoDoItem.call(item).select(&:incluida).each do |parte|
        somar(linhas, parte, parte.config) if parte.config[:needs_cut]
      end
    end
    linhas.values.sort_by { |l| [ l.peca ? 0 : 1, l.peca&.nome.to_s, l.tamanho ? 0 : 1, l.corte&.filename.to_s, l.tamanho&.position.to_i ] }
  end

  private

  def somar(linhas, parte, config)
    parte.numeros.each do |numero|
      chave = [ parte.peca&.id, numero.tamanho&.id, config[:pecas_por_par], config[:espelhada] ]
      linha = linhas[chave] ||= Linha.new(peca: parte.peca, tamanho: numero.tamanho, quantidades: Hash.new(0),
                                          pecas_por_par: config[:pecas_por_par], espelhada: config[:espelhada])
      linha.quantidades[numero.numero] += numero.quantidade
    end
  end
end
