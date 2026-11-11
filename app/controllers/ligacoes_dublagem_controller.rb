# One ligação of the dublagem network on its own page (rede editável 2/2a,
# decided 09-10/11/2026, Q4c, canvas "Rede editável — C"): the whole form,
# where it is used and its histórico. Seeing it is the rede's (estoque: ver,
# the team); creating, saving and trashing take the "Editar a rede de
# dublagens" action alone (Q7a) — without it the form is read only. A
# construção's card creates one too, as JSON (Dublagem 5b1b, "Adicionar à
# rede"), its histórico saying so.
class LigacoesDublagemController < ApplicationController
  exige :estoque, :ver
  exige_equipe
  exige_acao :editar_rede_de_dublagens, only: %i[new create update destroy]

  # A ligação in the trash still opens (lookups by uuid stay unscoped), read only.
  def show
    @ligacao = ligacao_por_uuid(params[:id])
    preparar_pagina
  end

  # grupo: the group the page came from, picked as the first one.
  # Usage: GET /rede-de-dublagens/ligacoes/new?grupo=<uuid>
  def new
    @ligacao = visiveis(LigacaoDublagem).new(dubla: "antes", grupo_a: visiveis(GrupoMaterial).find_by(uuid: params[:grupo]))
    preparar_pagina
  end

  # Usage: POST /rede-de-dublagens/ligacoes, ligacao[grupo_a_uuid|grupo_b_uuid|lado|dubla|a_confirmar[]],
  #        ligacao[ligantes][][grupo_uuid|micras], ligacao[situacoes][<chave>][][grupo_uuid|micras]
  #        As JSON (5b1b, origem=construcao): { ok: true, id: <uuid> } or { ok: false, error: "…" }
  def create
    @ligacao = visiveis(LigacaoDublagem).new
    return salvar(:new) unless request.format.json?

    salva = SalvarLigacao.new(@ligacao, dados_do_formulario, origem: params[:origem], **contexto_do_salvar).call
    return render json: { ok: true, id: @ligacao.uuid } if salva

    render json: { ok: false, error: @ligacao.errors.full_messages.to_sentence }, status: :unprocessable_content
  end

  def update
    @ligacao = ligacao_por_uuid(params[:id])
    return redirect_to rede_ligacao_path(@ligacao), alert: "#{@ligacao.nome} está na lixeira: restaure-a na Lixeira para mudar." if @ligacao.excluido?

    salvar(:show)
  end

  def destroy
    ligacao = ligacao_por_uuid(params[:id])
    ligacao.excluir!(**autoria)
    redirect_to rede_de_dublagens_path, notice: "#{ligacao.nome}: foi para a lixeira."
  end

  private

  def ligacao_por_uuid(uuid)
    visiveis(LigacaoDublagem).includes(:grupo_a, :grupo_b, ligantes: %i[grupo_material situacao_dublagem]).por_uuid!(uuid)
  end

  def salvar(tela)
    salvo = SalvarLigacao.new(@ligacao, dados_do_formulario, **contexto_do_salvar).call
    return redirect_to rede_ligacao_path(@ligacao), notice: "#{@ligacao.nome}: salva." if salvo

    preparar_pagina
    flash.now[:alert] = @ligacao.errors.full_messages.to_sentence
    render tela, status: :unprocessable_content
  end

  def contexto_do_salvar = { grupos: visiveis(GrupoMaterial), situacoes: visiveis(SituacaoDublagem), user: Current.user }

  def dados_do_formulario
    linha = %i[grupo_uuid micras]
    chaves = visiveis(SituacaoDublagem).pluck(:chave)
    params.require(:ligacao).permit(:grupo_a_uuid, :grupo_b_uuid, :lado, :dubla, dubla: [], a_confirmar: [], ligantes: linha,
                                    situacoes: chaves.index_with { linha }).to_h
  end

  def preparar_pagina
    @grupos = visiveis(GrupoMaterial).order(:nome)
    @situacoes = visiveis(SituacaoDublagem).order(:id)
    @editavel = pode_acao?(:editar_rede_de_dublagens) && !@ligacao.excluido?
    return if @ligacao.new_record?

    @construcoes = UsoDaLigacao.new(@ligacao, construcoes: visiveis(Construcao)).call
    @alteracoes = visiveis(AlteracaoDaRede).where(registro: @ligacao).recentes.includes(:user)
  end
end
