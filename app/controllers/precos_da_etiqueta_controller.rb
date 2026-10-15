# A DTF size's agreed unit price (Etapa 2.6c, decided 14/10/2026, D6), over
# the one calculated from the price per meter: it stops following the
# recalculation and comes first in a pedido; blank goes back to the
# calculated. On the etiqueta's page, the team's with "ver valores".
class PrecosDaEtiquetaController < ApplicationController
  include NumeroDigitado

  exige :artes, :editar
  exige_acao :ver_valores
  exige_equipe

  # Usage: PATCH /arquivos/:arquivo_id/preco_dtf, preco_unidade_combinado=0,30 (arquivo_id = the size's file)
  def update
    arquivo = visiveis(Arquivo).ativos.where(arte: Arte.where(tipo: "dtf")).por_uuid!(params[:arquivo_id])
    arquivo.preco_unidade_combinado = decimal_digitado(params[:preco_unidade_combinado])
    return redirect_to arquivo, alert: arquivo.errors.full_messages.to_sentence unless arquivo.save

    redirect_to arquivo, notice: "Unit price of #{arquivo.rotulo_de_tamanho || arquivo.filename}: #{arquivo.preco_unidade_combinado ? "agreed" : "back to the calculated"}."
  end
end
