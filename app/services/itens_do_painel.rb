# A pedido's items as rows of the Painel (Painel 1/4, Q2a): each item's
# lines of every stage, from the pedido's EstadoDasEtapas. The Corte's lines
# are per part × size × material of the whole pedido — not an item's —, so
# an item shows the pedido's Corte; a draft's stages are not computed yet.
#
# Usage: ItensDoPainel.call(pedido).first.celulas["impressao"].texto # => "2/4"
class ItensDoPainel
  Item = Struct.new(:item, :celulas, keyword_init: true) do
    # Usage: item.nome # => "Bluey · 001-TNS"
    def nome
      item.arte&.titulo.presence || item.arquivo&.filename || "Item"
    end
  end

  def self.call(pedido)
    new(pedido).call
  end

  def initialize(pedido)
    @pedido = pedido
    @estados = pedido.saiu_do_rascunho? ? EstadoDasEtapas.call(pedido) : {}
  end

  def call
    @pedido.itens_pedido.includes(:arte, :arquivo).order(:id).map do |item|
      Item.new(item: item, celulas: celulas_do(item))
    end
  end

  private

  def celulas_do(item)
    @estados.to_h do |chave, situacoes|
      do_item = situacoes.values.select { |s| s.linha.referencia.nil? || s.linha.referencia == item.uuid }
      [ LinhaDoPainel::COLUNA_DA_ETAPA.fetch(chave, chave), CelulaDoPainel.da_etapa(do_item, confirmado: @pedido.em_producao?) ]
    end
  end
end
