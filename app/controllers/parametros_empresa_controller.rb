# The dono's production parameters (Etapa 2.2, 1/3; decided 07/10/2026): the
# paper's width (an arte's meters per piece) and how far a baixa's metragem
# may fall below / go above the expected before the operator is warned.
# Etapa 2.4 adds the rest of the dono's parameters here; Etapa 2.3 turns the
# paper into a material.
class ParametrosEmpresaController < ApplicationController
  exige_dono

  def edit
    @empresa = Empresa.atual
  end

  # Usage: PATCH /parametros (empresa[largura_papel_mm|tolerancia_abaixo_pct|tolerancia_acima_pct])
  def update
    @empresa = Empresa.atual
    return redirect_to edit_parametros_path, notice: "Production parameters saved." if @empresa.update(parametros)

    flash.now[:alert] = @empresa.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_content
  end

  private

  def parametros
    params.require(:empresa).permit(:largura_papel_mm, :tolerancia_abaixo_pct, :tolerancia_acima_pct)
  end
end
