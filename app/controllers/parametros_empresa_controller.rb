# The dono's production parameters (Etapa 2.2, 1/3; decided 07/10/2026): the
# paper's width (an arte's meters per piece) and how far a baixa's metragem
# may fall below / go above the expected before the operator is warned.
# Etapa 2.4 adds the rest of the dono's parameters here. Since Etapa 2.3 the
# paper is a material: the default paper's width replaces the typed one.
class ParametrosEmpresaController < ApplicationController
  exige_dono
  # The empresa's own parameters: the dono's, never a client's records.
  nao_le_registros

  def edit
    @empresa = Empresa.atual
  end

  # Usage: PATCH /parametros (empresa[largura_papel_mm|tolerancia_abaixo_pct|tolerancia_acima_pct|custo_impressao_metro|custo_corte_peca],
  #   Etapa 2.6a: empresa[largura_filme_dtf_mm|margem_filme_dtf_mm|espacamento_dtf_mm|fileiras_extras_dtf])
  def update
    @empresa = Empresa.atual
    return redirect_to edit_parametros_path, notice: "Production parameters saved." if @empresa.update(parametros)

    flash.now[:alert] = @empresa.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_content
  end

  private

  def parametros
    dados = params.require(:empresa).permit(:papel_padrao_uuid, :largura_papel_mm, :tolerancia_abaixo_pct, :tolerancia_acima_pct,
                                            :custo_impressao_metro, :custo_corte_peca,
                                            :largura_filme_dtf_mm, :margem_filme_dtf_mm, :espacamento_dtf_mm, :fileiras_extras_dtf)
    papel = dados.delete(:papel_padrao_uuid)
    dados[:papel_padrao] = visiveis(MateriaPrima).papeis.find_by(uuid: papel) if papel
    # Etapa 2.4: "4,50" as typed; blank = not set.
    %i[custo_impressao_metro custo_corte_peca].each { |campo| dados[campo] = decimal_digitado(dados[campo]) if dados.key?(campo) }
    # Etapa 2.6a: "1,5" mm as typed.
    dados[:espacamento_dtf_mm] = decimal_digitado(dados[:espacamento_dtf_mm]) if dados.key?(:espacamento_dtf_mm)
    dados
  end

  def decimal_digitado(valor)
    valor.to_s.strip.tr(",", ".").presence
  end
end
