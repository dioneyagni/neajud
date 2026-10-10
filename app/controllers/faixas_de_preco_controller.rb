# A molde's price per pair by band of the grade (Etapa 2.4, decided
# 09/10/2026), edited on the molde page by whoever sees values and edits the
# catalog. Comma decimals ("9,50") are accepted.
class FaixasDePrecoController < ApplicationController
  exige :catalogo, :editar
  exige_acao :ver_valores
  before_action :set_molde

  # Usage: POST /moldes/:molde_id/faixas (faixa[tamanho_inicial|tamanho_final|preco_par])
  def create
    faixa = @molde.faixas_de_preco.new(dados_da_faixa)
    responder(faixa.save, faixa, "Price #{faixa.rotulo} saved.")
  end

  # Usage: PATCH /moldes/:molde_id/faixas/:id
  def update
    faixa = @molde.faixas_de_preco.por_uuid!(params[:id])
    responder(faixa.update(dados_da_faixa), faixa, "Price #{faixa.rotulo} saved.")
  end

  # Physical on purpose, like removing a part: confirmed pedidos keep the
  # price they were confirmed with.
  def destroy
    faixa = @molde.faixas_de_preco.por_uuid!(params[:id])
    faixa.destroy!
    redirect_to molde_path(@molde, anchor: "molde-precos"), notice: "Price #{faixa.rotulo} removed."
  end

  private

  def set_molde
    @molde = visiveis(Molde).por_uuid!(params[:molde_id])
  end

  def dados_da_faixa
    dados = params.require(:faixa).permit(:tamanho_inicial, :tamanho_final, :preco_par)
    dados[:tamanho_final] = dados[:tamanho_inicial] if dados[:tamanho_final].blank?
    dados[:preco_par] = dados[:preco_par].to_s.strip.tr(",", ".") if dados.key?(:preco_par)
    dados
  end

  def responder(salvou, faixa, aviso)
    mensagem = salvou ? { notice: aviso } : { alert: faixa.errors.full_messages.to_sentence }
    redirect_to molde_path(@molde, anchor: "molde-precos"), **mensagem
  end
end
