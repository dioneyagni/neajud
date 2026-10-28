# A tecido draft's own settings (Etapa 2.7a, decided 16/10/2026): its client
# and each item's material, meters and width (whose fabric moved to
# MateriaisDoPedidoController in 2.3d1, shared by every type). The cliente final
# changes all of it on his draft but the width — a production setting, how
# far the RIP repeats the module, the team's — and the client (D4,
# AjustesDoPedidoSemCorte).
class PedidosTecidoController < ApplicationController
  include AjustesDoPedidoSemCorte
  include NumeroDigitado

  # Usage: PATCH /pedidos/:uuid/tecido, client_uuid=… (the team's)
  def update
    atualizar_pedido
  end

  # Usage: PATCH /pedidos/:uuid/tecido/item, item_uuid=…, materia_prima_uuid=…, metros=12,5, largura_mm=1500 (the team's)
  def item
    item = @pedido.itens_pedido.por_uuid!(params[:item_uuid])
    return redirect_to resumo_pedido_path(@pedido), alert: "The width is the team's to set" if cliente_final? && params.key?(:largura_mm)

    item.assign_attributes(campos_do_item(item))
    return redirect_to resumo_pedido_path(@pedido), notice: "#{item.arte.titulo}: updated." if item.save

    redirect_to resumo_pedido_path(@pedido), alert: "#{item.arte.titulo}: #{item.errors.full_messages.to_sentence}"
  end

  private

  def tipo_do_pedido = "tecido"

  # Only the fields sent: a blank material unlinks it, blank meters leave
  # the item at 0 m (a pendência), a blank width follows the material's.
  def campos_do_item(item)
    campos = {}
    campos[:metros] = decimal_digitado(params[:metros]) if params.key?(:metros)
    campos[:largura_mm] = params[:largura_mm].presence if params.key?(:largura_mm)
    campos[:materia_prima] = material_do_item(item) if params.key?(:materia_prima_uuid)
    campos
  end

  # Dublagem 1/5: what prints; the item's own material stays allowed even if
  # its group stopped printing, since the form sends it back with the meters.
  def material_do_item(item)
    uuid = params[:materia_prima_uuid].presence
    return nil unless uuid
    return item.materia_prima if item.materia_prima&.uuid == uuid

    visiveis(MateriaPrima).estampaveis.por_uuid!(uuid)
  end
end
