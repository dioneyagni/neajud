# A DTF draft's own settings (Etapa 2.6b1, decided 13/10/2026): delivery on
# the roll or cut, the pedido's default extra rows and each line's own — the
# cliente final changes these on his draft (D5: he controls what he needs
# beyond) —, and the pedido's client, the team's (D4: the client is the
# pedido's, not the etiqueta's).
class PedidosDtfController < ApplicationController
  exige :pedidos, :editar
  before_action :set_pedido
  before_action :recusar_fora_do_rascunho

  # Usage: PATCH /pedidos/:uuid/dtf, entrega=cortada, fileiras_extras=1, client_uuid=… (the team's)
  def update
    # The team's only: a cliente final's pedido is always his own.
    return redirect_to resumo_pedido_path(@pedido), alert: "The pedido's client is the team's to choose" if cliente_final? && params.key?(:client_uuid)

    @pedido.assign_attributes(params.permit(:entrega, :fileiras_extras))
    @pedido.client = params[:client_uuid].presence && visiveis(Client).ativos.por_uuid!(params[:client_uuid]) if params.key?(:client_uuid)
    return redirect_to resumo_pedido_path(@pedido), notice: "Pedido updated." if @pedido.save

    redirect_to resumo_pedido_path(@pedido), alert: @pedido.errors.full_messages.to_sentence
  end

  # One line's own extra rows; blank goes back to the pedido's.
  # Usage: PATCH /pedidos/:uuid/dtf/fileiras, item_uuid=…, tamanho_nome=P, fileiras_extras=2
  def fileiras
    grade = @pedido.itens_pedido.por_uuid!(params[:item_uuid]).grades.find_by!(tamanho_nome: params[:tamanho_nome].to_s)
    return redirect_to resumo_pedido_path(@pedido), alert: grade.errors.full_messages.to_sentence unless grade.update(fileiras_extras: params[:fileiras_extras].presence)

    redirect_to resumo_pedido_path(@pedido), notice: "Extra rows of #{grade.tamanho_nome}: #{grade.fileiras_extras || "the pedido's (#{@pedido.fileiras_extras})"}."
  end

  private

  def set_pedido
    @pedido = visiveis(Pedido).where(tipo: "dtf").por_uuid!(params[:uuid])
  end

  def recusar_fora_do_rascunho
    return if @pedido.editavel?(cliente_final: cliente_final?)

    redirect_to resumo_pedido_path(@pedido), alert: "#{@pedido.rotulo_lixeira} is #{@pedido.excluido? ? "in the trash" : @pedido.status}; it changes only while editable"
  end
end
