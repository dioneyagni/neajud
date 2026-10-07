# What a pedido sends to the printer (Etapa 1.2, 3/3 parte 3c, decided
# 06/10/2026): per item (an arte), one line per file to print — part, DXF
# size, side — with the ordered numbers it serves and the pieces, from
# ResolucaoDoItem. Unlike the Corte page, parts "não corta" are printed too.
#
# Pieces = pairs × the molde part's pecas_por_par; a side's file prints half
# of them. A single file of a mirrored part prints them all, half mirrored
# (por_lado). What is missing (no file, no DXF, one side) is a line too.
#
# Usage: ImpressaoPedidoService.call(pedido).first.linhas.first.pecas # => 20
class ImpressaoPedidoService
  Linha = Struct.new(:peca, :tamanho, :arquivo, :lado, :origem, :pendencia, :quantidades, :pecas_por_par, :espelhada, keyword_init: true) do
    def pares
      quantidades.values.sum
    end

    # Usage: linha.pecas # => 10 (10 pairs × 2, one side's file: half)
    def pecas
      lado ? pares * pecas_por_par / 2 : pares * pecas_por_par
    end

    # A mirrored part printed from one file: pieces of each side.
    def por_lado
      espelhada && lado.nil? && arquivo ? pecas / 2 : nil
    end
  end

  Grupo = Struct.new(:item, :linhas, keyword_init: true)

  def self.call(pedido)
    new(pedido).call
  end

  def initialize(pedido)
    @pedido = pedido
  end

  def call
    itens = @pedido.itens_pedido.includes(:grades, :arte, :arquivo, item_pedido_pecas: :peca).order(:id)
    itens.map { |item| Grupo.new(item: item, linhas: linhas_do_item(item)) }
  end

  private

  def linhas_do_item(item)
    linhas = {}
    ResolucaoDoItem.call(item).select(&:incluida).each do |parte|
      parte.numeros.each { |numero| entradas(numero).each { |entrada| somar(linhas, parte, numero, **entrada) } }
    end
    linhas.values.sort_by { |l| [ l.peca&.nome.to_s, l.tamanho ? l.tamanho.position.to_i : Float::INFINITY, l.lado.to_s ] }
  end

  # What a number prints: each side's file (or the missing side), else its
  # one file or its pendência.
  def entradas(numero)
    return [ { arquivo: numero.arquivo, lado: nil, pendencia: numero.pendencia } ] unless numero.lados

    numero.lados.map { |lado, arquivo| { arquivo: arquivo, lado: lado, pendencia: (:sem_lado unless arquivo) } }
  end

  def somar(linhas, parte, numero, arquivo:, lado:, pendencia:)
    chave = [ parte.peca&.id, numero.tamanho&.id, arquivo&.id, lado, pendencia ]
    linha = linhas[chave] ||= Linha.new(peca: parte.peca, tamanho: numero.tamanho, arquivo: arquivo, lado: lado,
                                        origem: (numero.origem || :producao if arquivo), pendencia: pendencia, quantidades: Hash.new(0),
                                        pecas_por_par: parte.config[:pecas_por_par], espelhada: parte.config[:espelhada])
    linha.quantidades[numero.numero] += numero.quantidade
  end
end
