# Labels of the kinds a cliente final may see (TiposParaCliente, Etapa 2.8 3a).
module VisibilidadeHelper
  ROTULOS_TIPO = {
    "pedidos" => [ "Pedidos", "his pedidos and their progress" ],
    "moldes" => [ "Moldes", "his moldes and referências" ],
    "estoque" => [ "Estoque", "his material movements and balances" ],
    "original" => [ "Arquivo original", "downloading the original files (previews are always shown)" ],
    "cortes" => [ "Cortes (DXF)", "the cortes, their sizes and the pedido's Corte page" ],
    "valores" => [ "Valores", "the price per pair (never the cost or the margin)" ]
  }.freeze

  # Usage: rotulo_do_tipo("cortes") # => "Cortes (DXF)"
  def rotulo_do_tipo(tipo)
    ROTULOS_TIPO.fetch(tipo).first
  end

  # Usage: descricao_do_tipo("valores")
  def descricao_do_tipo(tipo)
    ROTULOS_TIPO.fetch(tipo).last
  end

  # Usage: estado_do_tipo(true) # => "open"
  def estado_do_tipo(aberto)
    aberto ? "open" : "closed"
  end
end
