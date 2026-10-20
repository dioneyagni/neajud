# Confirming a pedido (moved out of PedidosController in Etapa 2.3d2, which
# kept it under 500 lines): the checks, what is written so a later change
# never moves a confirmed pedido, the calçado's split per client, and the
# stock out of each pedido confirmed (SaidaDoPedido) — its warnings shown,
# never blocking.
#
# Usage: include ConfirmacaoDoPedido (PedidosController#confirmar, POST /pedidos/:uuid/confirmar)
module ConfirmacaoDoPedido
  extend ActiveSupport::Concern

  def confirmar
    return redirect_to pedidos_path, alert: "Pedido already confirmed." unless @pedido.confirmavel?

    bloqueios = @pedido.bloqueios_confirmacao
    if bloqueios.any?
      return redirect_to resumo_pedido_path(@pedido),
                         alert: "Não é possível confirmar: #{bloqueios.map(&:descricao).join("; ")}."
    end

    return confirmar_sem_corte if @pedido.cliente_do_pedido?

    confirmar_calcado
  end

  private

  def confirmar_calcado
    @pedido.gravar_precos!
    @pedido.gravar_dono_do_tecido!
    items_by_client = @pedido.itens_pedido.includes(:arquivo).group_by { |i| i.arquivo.client_id }

    if items_by_client.size == 1
      @pedido.update!(status: "confirmado", client_id: items_by_client.keys.first)
      return confirmado([ @pedido ], "Pedido confirmed.")
    end

    novos = items_by_client.map { |client_id, itens| pedido_do_cliente(client_id, itens) }
    @pedido.update!(status: "cancelado")
    confirmado(novos, "Pedido confirmed! #{novos.size} order(s) created.")
  end

  # The calçado split: one confirmed pedido per client of the artes.
  def pedido_do_cliente(client_id, itens)
    novo = visiveis(Pedido).create!(client_id: client_id, status: "confirmado", dono_tecido: @pedido.dono_tecido,
                                    material_impressao_id: @pedido.material_impressao_id)
    itens.each do |item|
      novo_item = novo.itens_pedido.create!(arquivo: item.arquivo, arte: item.arte, materia_prima: item.materia_prima, dono_tecido: item.dono_tecido)
      item.grades.each { |g| novo_item.grades.create!(tamanho_nome: g.tamanho_nome, quantidade: g.quantidade, preco_par: g.preco_par) }
      novo_item.copiar_pecas_de!(item)
    end
    novo
  end

  # A DTF or tecido pedido is its client's whatever its artes' owners (Etapa
  # 2.6b1 D4, 2.7a): never split. A DTF's fit and prices are written (2.6c),
  # so a later version, film or price change never moves what was confirmed;
  # a tecido's prices too (2.7b).
  def confirmar_sem_corte
    Pedido.transaction do
      if @pedido.dtf?
        EncaixeDoPedidoDtf.gravar!(@pedido)
        # Etapa 2.6c: the prices too, read on the fit just written.
        ValoresDoPedidoDtf.gravar!(@pedido.reload)
      end
      # Etapa 2.7b: each tecido item's starting and charged prices.
      ValoresDoPedidoTecido.gravar!(@pedido) if @pedido.tecido?
      @pedido.gravar_dono_do_tecido!
      @pedido.update!(status: "confirmado")
    end
    # Etapa 2.6b2: the files the fit turned, for the RIP.
    LinhasDeProducao.call(@pedido, EtapasProducao.etapa("dtf", "impressao")).each { |linha| ArquivoDtfParaRip.new(linha).preparar! } if @pedido.dtf?
    confirmado([ @pedido ], "Pedido confirmed.")
  end

  # Etapa 2.3d2: each pedido's stock out; what took nothing is warned about.
  def confirmado(pedidos, aviso)
    sem_saida = pedidos.flat_map { |pedido| SaidaDoPedido.call(pedido) }
    session.delete(:current_pedido_uuid) if session[:current_pedido_uuid] == @pedido.uuid
    flash[:alert] = "No stock out: #{sem_saida.uniq.join("; ")}." if sem_saida.any?
    redirect_to pedidos_path, notice: aviso
  end
end
