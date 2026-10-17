# A tecido draft's own settings (Etapa 2.7a, decided 16/10/2026): whose
# fabric it is printed on, once for the whole pedido (the client's or the
# empresa's), and each item's material, meters and width. The cliente final
# changes all of it on his draft but the width — a production setting, how
# far the RIP repeats the module, the team's — and the client (D4,
# AjustesDoPedidoSemCorte).
class PedidosTecidoController < ApplicationController
  include AjustesDoPedidoSemCorte
  include NumeroDigitado

  # Usage: PATCH /pedidos/:uuid/tecido, dono_tecido=empresa, client_uuid=… (the team's)
  def update
    atualizar_pedido(:dono_tecido)
  end

  # Usage: PATCH /pedidos/:uuid/tecido/item, item_uuid=…, materia_prima_uuid=…, metros=12,5, largura_mm=1500 (the team's)
  def item
    item = @pedido.itens_pedido.por_uuid!(params[:item_uuid])
    return redirect_to resumo_pedido_path(@pedido), alert: "The width is the team's to set" if cliente_final? && params.key?(:largura_mm)

    item.assign_attributes(campos_do_item)
    return redirect_to resumo_pedido_path(@pedido), notice: "#{item.arte.titulo}: updated." if item.save

    redirect_to resumo_pedido_path(@pedido), alert: "#{item.arte.titulo}: #{item.errors.full_messages.to_sentence}"
  end

  private

  def tipo_do_pedido = "tecido"

  # Only the fields sent: a blank material unlinks it, blank meters leave
  # the item at 0 m (a pendência), a blank width follows the material's.
  def campos_do_item
    campos = {}
    campos[:metros] = decimal_digitado(params[:metros]) if params.key?(:metros)
    campos[:largura_mm] = params[:largura_mm].presence if params.key?(:largura_mm)
    campos[:materia_prima] = params[:materia_prima_uuid].presence && tecidos.por_uuid!(params[:materia_prima_uuid]) if params.key?(:materia_prima_uuid)
    campos
  end

  def tecidos
    visiveis(MateriaPrima).where(tipo: "tecido")
  end
end
