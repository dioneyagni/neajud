# The dono's production parameters (Etapa 2.2, 1/3; decided 07/10/2026): the
# paper's width (an arte's meters per piece) and how far a baixa's metragem
# may fall below / go above the expected before the operator is warned.
# Etapa 2.4 adds the rest of the dono's parameters here. Since Etapa 2.3 the
# paper is a material: the default paper's width replaces the typed one.
class ParametrosEmpresaController < ApplicationController
  exige_dono

  def edit
    @empresa = Empresa.atual
  end

  # Usage: PATCH /parametros (empresa[largura_papel_mm|tolerancia_abaixo_pct|tolerancia_acima_pct|custo_impressao_metro|custo_corte_peca])
  def update
    @empresa = Empresa.atual
    return redirect_to edit_parametros_path, notice: "Production parameters saved." if @empresa.update(parametros)

    flash.now[:alert] = @empresa.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_content
  end

  private

  def parametros
    dados = params.require(:empresa).permit(:papel_padrao_uuid, :largura_papel_mm, :tolerancia_abaixo_pct, :tolerancia_acima_pct,
                                            :custo_impressao_metro, :custo_corte_peca)
    papel = dados.delete(:papel_padrao_uuid)
    dados[:papel_padrao] = MateriaPrima.papeis.find_by(uuid: papel) if papel
    # Etapa 2.4: "4,50" as typed; blank = not set.
    %i[custo_impressao_metro custo_corte_peca].each { |campo| dados[campo] = dados[campo].to_s.strip.tr(",", ".").presence if dados.key?(campo) }
    dados
  end
end
