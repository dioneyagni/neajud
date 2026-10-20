# What the pedido page says about where its materials come from (Etapa
# 2.3d1): whose fabric — the pedido's choice or what it inherits, and from
# which level — and the paper or DTF film it prints on.
module MateriaisDoPedidoHelper
  NIVEIS_DO_DONO = { pedido: "escolhido no pedido", molde: "do molde", cliente: "do cadastro do cliente", padrao: "padrão", item: "gravado na confirmação" }.freeze

  # Usage: dono_do_tecido_do_pedido(pedido) # => "Da empresa (do molde)"
  def dono_do_tecido_do_pedido(pedido)
    origem = dono_efetivo_do_pedido(pedido)
    origem ? "#{origem.rotulo} (#{NIVEIS_DO_DONO.fetch(origem.nivel)})" : "Varia por molde"
  end

  # The blank option of the pedido's select: what it inherits.
  # Usage: rotulo_do_dono_herdado(pedido) # => "Herdar: do cliente (do cadastro do cliente)"
  def rotulo_do_dono_herdado(pedido)
    origem = DonoDoTecido.herdado(pedido)
    origem ? "Herdar: #{origem.rotulo.downcase} (#{NIVEIS_DO_DONO.fetch(origem.nivel)})" : "Herdar: o de cada molde"
  end

  # Usage: material_de_impressao_do_pedido(pedido) # => "Papel-Branco-1.60-90g" or "1600 mm (sem material)"
  def material_de_impressao_do_pedido(pedido)
    material = pedido.material_de_impressao
    return material.nome_completo if material

    largura = pedido.dtf? ? Empresa.atual&.largura_filme_dtf_efetiva_mm : pedido.largura_do_papel_mm
    "#{largura} mm (sem material cadastrado)"
  end

  private

  # A calçado draft without its own choice follows each item's molde.
  def dono_efetivo_do_pedido(pedido)
    return DonoDoTecido.do_pedido(pedido) if pedido.tecido? || pedido.dono_tecido || pedido.itens_pedido.any?(&:dono_tecido)

    DonoDoTecido.herdado(pedido)
  end
end
