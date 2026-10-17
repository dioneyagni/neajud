# A DTF draft's own settings (Etapa 2.6b1, decided 13/10/2026): delivery on
# the roll or cut, the pedido's default extra rows and each line's own — the
# cliente final changes these on his draft (D5: he controls what he needs
# beyond) —, and the pedido's client, the team's (D4: the client is the
# pedido's, not the etiqueta's; AjustesDoPedidoSemCorte).
class PedidosDtfController < ApplicationController
  include AjustesDoPedidoSemCorte

  # Usage: PATCH /pedidos/:uuid/dtf, entrega=cortada, fileiras_extras=1, client_uuid=… (the team's)
  def update
    atualizar_pedido(:entrega, :fileiras_extras)
  end

  # One line's own extra rows; blank goes back to the pedido's.
  # Usage: PATCH /pedidos/:uuid/dtf/fileiras, item_uuid=…, tamanho_nome=P, fileiras_extras=2
  def fileiras
    grade = @pedido.itens_pedido.por_uuid!(params[:item_uuid]).grades.find_by!(tamanho_nome: params[:tamanho_nome].to_s)
    return redirect_to resumo_pedido_path(@pedido), alert: grade.errors.full_messages.to_sentence unless grade.update(fileiras_extras: params[:fileiras_extras].presence)

    redirect_to resumo_pedido_path(@pedido), notice: "Extra rows of #{grade.tamanho_nome}: #{grade.fileiras_extras || "the pedido's (#{@pedido.fileiras_extras})"}."
  end

  private

  def tipo_do_pedido = "dtf"
end
