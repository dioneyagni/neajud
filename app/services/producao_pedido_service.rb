# What a pedido sends to the cutting table (Etapa 1.2, 3/3 parte 3b, decided
# 06/10/2026): one line per part × DXF size, with the ordered numbers it
# serves summed over every item whose part is checked, and the pieces to cut
# — pairs × the molde part's pecas_por_par, half right and half left when
# espelhada. Read from ResolucaoDoItem (the number's DXF size in the part).
# Parts marked "não corta" on the molde are left out (decided 06/10/2026:
# they never reach the table; they are printed only). Numbers no DXF serves
# stay in a line without size (they also block confirming). Lines are also
# per material (Etapa 2.2, 1/3): each roll is a cut of its own, and its width
# gives the expected metragem (the size's meters per piece × pieces).
# This is the single place production reads from — see Pedido#pecas_para_produzir.
#
# Usage: ProducaoPedidoService.call(pedido)
#   # => [#<Linha peca=Lateral tamanho=<29-30> quantidades={"29"=>4, "30"=>6} pecas_por_par=2 espelhada=true>]
class ProducaoPedidoService
  # Grade key used when an item has no tamanhos (a single total quantity).
  TOTAL_KEY = "_total".freeze

  # pecas_fixas: a reposição's line counts pieces, not pairs (Etapa 2.2, 4/4).
  Linha = Struct.new(:peca, :tamanho, :materia_prima, :quantidades, :pecas_por_par, :espelhada, :pecas_fixas, keyword_init: true) do
    def corte
      tamanho&.arquivo
    end

    def pares
      quantidades.values.sum
    end

    # Usage: linha.pecas # => 20 (10 pairs × 2)
    def pecas
      pecas_fixas || pares * pecas_por_par
    end

    # Pieces of each side of a mirrored part (nil when not mirrored).
    # Usage: linha.por_lado # => 10
    def por_lado
      espelhada && !pecas_fixas ? pecas / 2 : nil
    end

    # Meters of fabric this line should take, on its material's roll; nil
    # without material, size or a computed fit (EncaixeDoTamanho).
    # Usage: linha.metros_esperados # => 0.3662 (shown rounded, summed unrounded)
    def metros_esperados
      largura = materia_prima&.largura_mm
      por_peca = largura && tamanho&.metros_por_peca_em(largura)
      por_peca && (por_peca * pecas).round(4)
    end
  end

  # itens: only these items' lines (a reposição: the pieces missing from
  # them) — the stock out splits the fabric by each item's owner (Etapa 2.3d2).
  # Usage: ProducaoPedidoService.call(pedido, itens: pedido.itens_pedido.where(dono_tecido: "empresa"))
  def self.call(pedido, itens: nil)
    new(pedido, itens).call
  end

  def initialize(pedido, itens = nil)
    @pedido = pedido
    @itens = itens
  end

  def call
    return linhas_da_reposicao if @pedido.reposicao?

    linhas = {}
    itens = @itens ? @pedido.itens_pedido.where(id: @itens) : @pedido.itens_pedido
    itens.includes(:grades, :arte, :arquivo, :materia_prima, item_pedido_pecas: :peca).order(:id).each do |item|
      ResolucaoDoItem.call(item).select(&:incluida).each do |parte|
        somar(linhas, parte, item.materia_prima) if parte.config[:needs_cut]
      end
    end
    linhas.values.sort_by { |l| [ l.peca ? 0 : 1, l.peca&.nome.to_s, l.tamanho ? 0 : 1, l.corte&.filename.to_s, l.tamanho&.position.to_i ] }
  end

  private

  # A reposição (Etapa 2.2, 4/4): its missing pieces that cut, summed per
  # part × DXF size × material.
  def linhas_da_reposicao
    faltas = @itens ? @pedido.itens_reposicao.where(item_origem_id: @itens) : @pedido.itens_reposicao
    faltas = faltas.includes(:peca, :materia_prima, tamanho: :arquivo).select { |f| f.corta && f.refazer_corte }
    faltas.group_by { |f| [ f.peca, f.tamanho, f.materia_prima ] }.map do |(peca, tamanho, materia), grupo|
      Linha.new(peca: peca, tamanho: tamanho, materia_prima: materia, quantidades: {}, pecas_por_par: 1, espelhada: false, pecas_fixas: grupo.sum(&:pecas))
    end.sort_by { |l| [ l.peca&.nome.to_s, l.tamanho&.position.to_i ] }
  end

  def somar(linhas, parte, materia_prima)
    config = parte.config
    parte.numeros.each do |numero|
      chave = [ parte.peca&.id, numero.tamanho&.id, materia_prima&.id, config[:pecas_por_par], config[:espelhada] ]
      linha = linhas[chave] ||= Linha.new(peca: parte.peca, tamanho: numero.tamanho, materia_prima: materia_prima, quantidades: Hash.new(0),
                                          pecas_por_par: config[:pecas_por_par], espelhada: config[:espelhada])
      linha.quantidades[numero.numero] += numero.quantidade
    end
  end
end
