# The dono's production parameters (Etapa 2.2, 1/3; decided 07/10/2026): the
# paper's width (an arte's meters per piece) and how far a baixa's metragem
# may fall below / go above the expected before the operator is warned.
# Etapa 2.4 adds the rest of the dono's parameters here. Since Etapa 2.3 the
# paper is a material: the default paper's width replaces the typed one.
class ParametrosEmpresaController < ApplicationController
  include NumeroDigitado
  exige_dono
  # The empresa's own parameters: the dono's, never a client's records.
  nao_le_registros

  def edit
    @empresa = Empresa.atual
  end

  # Usage: PATCH /parametros (empresa[largura_papel_mm|tolerancia_abaixo_pct|tolerancia_acima_pct|custo_impressao_metro|custo_corte_peca],
  #   Etapa 2.6a: empresa[largura_filme_dtf_mm|margem_filme_dtf_mm|espacamento_dtf_mm|fileiras_extras_dtf],
  #   Etapa 2.6c: empresa[preco_metro_dtf|preco_corte_dtf|cobranca_dtf|cobrar_excedente_dtf],
  #   Etapa 2.7b: empresa[preco_impressao_metro_tecido|metragem_minima_tecido])
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
                                            :largura_filme_dtf_mm, :margem_filme_dtf_mm, :espacamento_dtf_mm, :fileiras_extras_dtf,
                                            :preco_metro_dtf, :preco_corte_dtf, :cobranca_dtf, :cobrar_excedente_dtf,
                                            :preco_impressao_metro_tecido, :metragem_minima_tecido)
    papel = dados.delete(:papel_padrao_uuid)
    dados[:papel_padrao] = visiveis(MateriaPrima).papeis.find_by(uuid: papel) if papel
    # Etapa 2.4: "4,50" as typed; blank = not set.
    %i[custo_impressao_metro custo_corte_peca].each { |campo| dados[campo] = decimal_digitado(dados[campo]) if dados.key?(campo) }
    # Etapa 2.6a: "1,5" mm as typed; 2.6c: the DTF's prices too.
    # 2.7b: the tecido's price and minimum.
    %i[espacamento_dtf_mm preco_metro_dtf preco_corte_dtf preco_impressao_metro_tecido metragem_minima_tecido].each { |campo| dados[campo] = decimal_digitado(dados[campo]) if dados.key?(campo) }
    dados
  end
end
