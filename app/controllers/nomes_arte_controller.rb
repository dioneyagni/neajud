# An arte's Referência + Nome (Etapa 1.1, 5/5), and joining an arte uploaded
# twice into the original as a new version.
class NomesArteController < ApplicationController
  before_action :set_arte
  before_action { exigir!(pode?(@arte.area_de_acesso, :editar), "#{@arte.area_de_acesso}: editar") }

  # Usage: PATCH /arquivos/:uuid/nome_arte (referencia_uuid or nova_referencia, nome)
  def update
    if @arte.update(referencia: referencia_escolhida, nome: params[:nome].to_s.squish.presence)
      redirect_to @arte, notice: "Reference and name saved: #{@arte.nome_completo}"
    else
      redirect_to @arte, alert: "Could not save: #{@arte.errors.full_messages.to_sentence}"
    end
  end

  # Usage: POST /arquivos/:uuid/nome_arte/tornar_versao (original_uuid)
  def tornar_versao
    original = Arquivo.ativos.por_uuid!(params[:original_uuid])
    versao = JuntarArteRepetidaService.call(repetida: @arte, original: original, **autoria)
    redirect_to original, notice: "#{@arte.filename} is now version #{versao.version_number} of #{original.nome_completo}."
  rescue JuntarArteRepetidaService::Recusado => e
    redirect_to @arte, alert: e.message
  end

  private

  def set_arte
    @arte = Arquivo.ativos.where(category: "artes").por_uuid!(params[:arquivo_id])
  end

  # A typed new referência wins over the select; blank both = no referência.
  def referencia_escolhida
    return Referencia.do_molde!(@arte.molde, params[:nova_referencia]) if params[:nova_referencia].present? && @arte.molde
    return nil if params[:referencia_uuid].blank?

    @arte.molde.referencias.por_uuid!(params[:referencia_uuid])
  end
end
