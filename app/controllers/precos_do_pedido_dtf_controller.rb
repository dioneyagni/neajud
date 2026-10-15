# What a DTF draft charges (Etapa 2.6c, decided 13-14/10/2026): by meter or
# quantity and whether the excess is charged — blank follows the client's,
# else the dono's (D2) —, and the edited prices over the starting ones, which
# stay beside them to measure the discount (D3): the price per meter, per
# unit cut and each line's unit price. The team's, with "ver valores".
class PrecosDoPedidoDtfController < ApplicationController
  include NumeroDigitado

  exige :pedidos, :editar
  exige_acao :ver_valores
  exige_equipe
  before_action :set_pedido

  # Usage: PATCH /pedidos/:uuid/dtf/precos, cobranca_dtf=metro, cobrar_excedente=false, preco_metro=110, preco_corte=
  def update
    @pedido.assign_attributes(escolhas)
    return redirect_to resumo_pedido_path(@pedido, anchor: "valores-dtf"), notice: "Pedido's prices updated." if @pedido.save

    redirect_to resumo_pedido_path(@pedido, anchor: "valores-dtf"), alert: @pedido.errors.full_messages.to_sentence
  end

  # One line's unit price; blank goes back to the starting one.
  # Usage: PATCH /pedidos/:uuid/dtf/preco_linha, item_uuid=…, tamanho_nome=P, preco_unidade=0,25
  def linha
    grade = @pedido.itens_pedido.por_uuid!(params[:item_uuid]).grades.find_by!(tamanho_nome: params[:tamanho_nome].to_s)
    preco = decimal_digitado(params[:preco_unidade])
    return redirect_to resumo_pedido_path(@pedido, anchor: "valores-dtf"), alert: "Unit price must be ≥ 0, got #{params[:preco_unidade].inspect}" if preco&.to_d&.negative?

    grade.update!(preco_unidade: preco)
    redirect_to resumo_pedido_path(@pedido, anchor: "valores-dtf"), notice: "Unit price of #{grade.tamanho_nome}: #{preco ? "edited" : "back to the starting one"}."
  end

  private

  def set_pedido
    @pedido = visiveis(Pedido).where(tipo: "dtf").por_uuid!(params[:uuid])
    return if @pedido.editavel?

    redirect_to resumo_pedido_path(@pedido), alert: "#{@pedido.rotulo_lixeira} is #{@pedido.excluido? ? "in the trash" : @pedido.status}; its prices change only while editable"
  end

  def escolhas
    {
      cobranca_dtf: params[:cobranca_dtf].presence, cobrar_excedente: params[:cobrar_excedente].presence,
      preco_metro: decimal_digitado(params[:preco_metro]), preco_corte: decimal_digitado(params[:preco_corte])
    }.select { |campo, _| params.key?(campo) }
  end
end
