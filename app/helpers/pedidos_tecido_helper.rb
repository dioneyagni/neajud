# The tecido pedido's page (Etapa 2.7a, decided 16/10/2026): widths in meters,
# the warning of a width past the paper and each fabric's balance of the
# pedido's fabric owner — information only, never a block.
module PedidosTecidoHelper
  # Usage: largura_em_metros(1600) # => "1,6 m"
  def largura_em_metros(largura_mm)
    largura_mm ? metros(largura_mm / 1000.0) : "—"
  end

  # Sublimation prints on the transfer paper: a fabric wider than the
  # default paper doesn't come out whole on it. A warning (decided 16/10/2026:
  # the factory may have a wider paper), nil when it fits.
  # Usage: aviso_de_largura(item) # => "Mais larga que o papel (1,6 m): confira se há papel para ela"
  def aviso_de_largura(item)
    papel = Empresa.atual&.largura_papel_efetiva_mm
    largura = item.largura_efetiva_mm
    return unless papel && largura && largura > papel

    "Mais larga que o papel (#{largura_em_metros(papel)}): confira se há papel para ela"
  end

  # The fabric's balance of the pedido's owner: the client's own material
  # here, or the empresa's — never shown to a cliente final, who sees only
  # his own (Visibilidade). nil when unknown.
  # Usage: saldo_do_tecido(pedido, material, SaldosDeEstoque.call(visiveis(MovimentoEstoque))) # => "30 m"
  def saldo_do_tecido(pedido, material, saldos)
    return metros(saldos.empresa(material)) if pedido.dono_tecido == "empresa" && !cliente_final?
    return unless pedido.dono_tecido == "cliente" && pedido.client

    metros(saldos.por_cliente(material)[pedido.client] || 0)
  end
end
