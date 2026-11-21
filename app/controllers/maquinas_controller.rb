# The factory's machines (Máquinas 1/5, decided 20/11/2026, canvas
# "Máquinas"): the list with each trabalho's machines and informado, a page
# per machine (name, what it does, the Corte do calçado's parameters,
# histórico) and the trash. The dono's, like the rest of Parâmetros.
class MaquinasController < ApplicationController
  exige_dono

  def index
    @maquinas = visiveis(Maquina).ativos.includes(:trabalhos).order(:nome)
    @ritmos = RitmoProducao.da_fabrica(visiveis(RitmoProducao).to_a, trabalhos: visiveis(TrabalhoDaMaquina).ativos)
  end

  def new
    @maquina = visiveis(Maquina).new
  end

  # Usage: POST /parametros/maquinas (maquina[nome], maquina[trabalhos][<chave>][marcado|por_hora|velocidade_mm_s|…])
  def create
    @maquina = visiveis(Maquina).new
    salvar(:new)
  end

  # A machine in the trash still opens (lookups by uuid stay unscoped), read only.
  def edit
    @maquina = maquina_por_uuid
    preparar_pagina
  end

  def update
    @maquina = maquina_por_uuid
    return redirect_to edit_parametros_maquina_path(@maquina), alert: "#{@maquina.nome} está na lixeira: restaure-a na Lixeira para mudar." if @maquina.excluido?

    salvar(:edit)
  end

  def destroy
    maquina = visiveis(Maquina).ativos.por_uuid!(params[:uuid])
    maquina.excluir!(**autoria)
    redirect_to parametros_maquinas_path, notice: "#{maquina.nome}: foi para a lixeira."
  end

  private

  def maquina_por_uuid
    visiveis(Maquina).includes(:trabalhos).por_uuid!(params[:uuid])
  end

  def salvar(tela)
    return redirect_to parametros_maquinas_path, notice: "#{@maquina.nome}: salva." if SalvarMaquina.new(@maquina, dados_da_maquina, user: Current.user).call

    preparar_pagina
    flash.now[:alert] = @maquina.errors.full_messages.to_sentence
    render tela, status: :unprocessable_content
  end

  def preparar_pagina
    @alteracoes = @maquina.new_record? ? [] : visiveis(AlteracaoDaMaquina).where(maquina: @maquina).recentes.includes(:user)
  end

  def dados_da_maquina
    campos = [ :marcado, *SalvarMaquina::CAMPOS ]
    params.require(:maquina).permit(:nome, trabalhos: TrabalhosDeMaquina.chaves.index_with { campos }).to_h
  end
end
