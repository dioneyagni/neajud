# The empresa's default of what a cliente final sees, by kind (Etapa 2.8, 3a;
# decided 10/10/2026): the dono's, like Funções. Each client's exceptions are
# on its page (VisibilidadeDoClienteController).
class VisibilidadePadraoController < ApplicationController
  exige_dono
  # The empresa's own setting: no client records read.
  nao_le_registros

  def edit
    @empresa = Empresa.atual
  end

  # Usage: PATCH /visibilidade (tipos[pedidos]=1&tipos[cortes]=0…)
  def update
    @empresa = Empresa.atual
    if @empresa.update(visibilidade_cliente: TiposParaCliente.padrao_da_empresa(@empresa).merge(TiposParaCliente.ler(tipos)))
      return redirect_to edit_visibilidade_path, notice: "Default visibility saved."
    end

    flash.now[:alert] = @empresa.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_content
  end

  private

  def tipos
    params.fetch(:tipos, {}).permit(*TiposParaCliente::TIPOS).to_h
  end
end
