# The material missing launched at a baixa or a delivery (EntradaDaFalta,
# decided 05/11/2026): the dialog's fields, and someone else's password
# checked with the sign-in's limit (SessionsController) — only on the
# requests that carry one, so a busy operator's baixas are never limited.
#
# Usage: include EntradaDaFaltaAutorizada
#        limita_senha_do_autorizador only: :entregar
#        Service.call(…, **campos_da_entrada)
#        render json: { ok: false, falta_material: r.mensagem, **dialogo_da_falta(r.faltas) }
module EntradaDaFaltaAutorizada
  extend ActiveSupport::Concern

  class_methods do
    def limita_senha_do_autorizador(only:)
      rate_limit to: 10, within: 3.minutes, only: only, name: "autorizador", if: -> { params.dig(:autorizador, :senha).present? },
                 with: -> { render json: { ok: false, error: "Too many password attempts; try again in a few minutes." }, status: :too_many_requests }
    end
  end

  private

  def campos_da_entrada
    { entradas: params[:entradas]&.to_unsafe_h, autorizador: params[:autorizador]&.permit(:email, :senha)&.to_h }
  end

  def dialogo_da_falta(faltas)
    { faltas: faltas.map(&:para_o_dialogo), pode_lancar: pode?(:estoque, :editar) }
  end
end
