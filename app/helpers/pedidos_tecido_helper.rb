# The tecido pedido's page (Etapa 2.7a, decided 16/10/2026): widths in meters,
# the warning of a width past the paper and each fabric's balance of the
# pedido's fabric owner — information only, never a block.
module PedidosTecidoHelper
  # Usage: largura_em_metros(1600) # => "1,6 m"
  def largura_em_metros(largura_mm)
    largura_mm ? metros(largura_mm / 1000.0) : "—"
  end

  # Sublimation prints on the transfer paper: a fabric wider than the
  # pedido's paper (since 2.3d1 its own, else the default) doesn't come out
  # whole on it. A warning (decided 16/10/2026: the factory may have a wider
  # paper), nil when it fits.
  # Usage: aviso_de_largura(item) # => "Mais larga que o papel (1,6 m): confira se há papel para ela"
  def aviso_de_largura(item)
    papel = item.pedido.largura_do_papel_mm
    largura = item.largura_efetiva_mm
    return unless papel && largura && largura > papel

    "Mais larga que o papel (#{largura_em_metros(papel)}): confira se há papel para ela"
  end

  # A fabric whose group prints with ressalvas (Dublagem 1/5): its text as a
  # warning, never a block; nil otherwise.
  # Usage: aviso_de_ressalva(item) # => "TNT estampa com ressalvas: a cor fica mais clara"
  def aviso_de_ressalva(item)
    grupo = item.materia_prima&.grupo_material
    return unless grupo&.com_ressalvas?

    "#{grupo.nome} estampa com ressalvas: #{grupo.ressalva}"
  end

  # The fabric's balance of the pedido's owner: the client's own material
  # here, or the empresa's — never shown to a cliente final, who sees only
  # his own (Visibilidade). nil when unknown.
  # Usage: saldo_do_tecido(pedido, material, SaldosDeEstoque.call(visiveis(MovimentoEstoque))) # => "30 m"
  def saldo_do_tecido(pedido, material, saldos)
    dono = DonoDoTecido.do_pedido(pedido).dono
    return metros(saldos.empresa(material)) if dono == "empresa" && !cliente_final?
    return unless dono == "cliente" && pedido.client

    metros(saldos.por_cliente(material)[pedido.client] || 0)
  end

  # Dublagem 4/5: the construções an item may be dubbed into — active, on
  # its superfície, the empresa's or the pedido's client's (Visibilidade
  # leaves a cliente final only those) — plus the one it has, which stays
  # listed even trashed (its pendência says so). Empty without a superfície.
  # Usage: construcoes_do_item(item).map(&:nome) # => ["Oxford Preto / Lona Branco-1.40 m"]
  def construcoes_do_item(item)
    return [] unless item.materia_prima

    opcoes = visiveis(Construcao).ativos.sobre(item.materia_prima).do_cliente_ou_da_empresa(item.pedido.client).includes(:client, :materia_prima).order(:nome).to_a
    item.construcao && opcoes.exclude?(item.construcao) ? opcoes + [ item.construcao ] : opcoes
  end

  # The dublado's balance in its construção's owner's stock: the client's,
  # or the empresa's — never the empresa's to a cliente final.
  # Usage: saldo_da_construcao(construcao, saldos) # => "12 m"
  def saldo_da_construcao(construcao, saldos)
    return metros(saldos.por_cliente(construcao.materia_prima)[construcao.client] || 0) if construcao.client

    metros(saldos.empresa(construcao.materia_prima)) unless cliente_final?
  end

  # When the item is dubbed against its estampa (D8), from the network; nil
  # when the network says nothing. The team's: it comes from the ligantes.
  # Usage: momento_da_dublagem(construcao) # => "dubla antes da estampa"
  def momento_da_dublagem(construcao)
    momentos = construcao.momentos_da_dublagem
    return if momentos.empty?

    momentos.one? ? "dubla #{momentos.first} da estampa" : "dubla parte antes, parte depois da estampa"
  end

  # The warning of a price below today's (20/10/2026), for the team that sees
  # prices — never a cliente final; nil when none is.
  # Usage: aviso_de_preco_abaixo(item) # => "Impressão R$ 15,00/m — abaixo do valor de hoje (R$ 18,50/m)"
  def aviso_de_preco_abaixo(item)
    abaixo = item.precos_abaixo_do_valor
    return if abaixo.empty? || cliente_final? || !pode_acao?(:ver_valores)

    abaixo.map { |cobranca, (preco, hoje)| "#{cobranca} #{reais(preco)}/m — abaixo do valor de hoje (#{reais(hoje)}/m)" }.join("; ")
  end
end
