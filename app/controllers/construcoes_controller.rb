# The construções (Dublagem 3/5, decided 30/10-02/11/2026; plano Etapa 2.9
# D6/D7): the list, and the form of the dublagem canvas — the situação, the
# chave of dublagens (5b1a: each card a material or an earlier letra above
# and below, with its ligante; MontagemDaChave), the suggested price and the
# final one. Every change in the form asks `montar`
# for the form again (each layer's options from the network, the price),
# nothing saved. The team's only: the ligante is the factory's (as the rede).
class ConstrucoesController < ApplicationController
  include NumeroDigitado
  exige :estoque, :ver, only: :index
  exige :estoque, :editar, only: %i[new create edit update montar]
  exige :estoque, :excluir, only: :destroy
  exige_equipe

  def index
    @construcoes = visiveis(Construcao).ativos.includes(:client, :materia_prima, camadas: %i[materia_prima ligante]).order(:nome)
    @servico = Empresa.atual&.preco_servico_dublagem
  end

  def new
    @construcao = visiveis(Construcao).new
    @construcao.definir_camadas([ { lado: "trama" }, { ordem_da_dublagem: 1 } ])
    preparar_montagem
  end

  # Usage: POST /construcoes, construcao[situacao|client_uuid|preco_final],
  #        construcao[dublagens][0][cima|baixo][escolha|do_cliente|lado], construcao[dublagens][0][ligante_uuid|posicao]
  #        (escolha: a material's uuid or "dublagem:<card>")
  def create
    @construcao = visiveis(Construcao).new
    aplicar_formulario(@construcao)
    return redirect_to edit_construcao_path(@construcao), notice: "#{@construcao.nome}: salva." if @construcao.save

    recusar(:new)
  end

  def edit
    @construcao = construcao_por_uuid(params[:id])
    preparar_montagem
  end

  # In use, only the final price changes (decision 5).
  def update
    @construcao = construcao_por_uuid(params[:id])
    @construcao.em_uso? ? @construcao.preco_final = decimal_digitado(params.dig(:construcao, :preco_final)) : aplicar_formulario(@construcao)
    return redirect_to edit_construcao_path(@construcao), notice: "#{@construcao.nome}: salva." if @construcao.save

    recusar(:edit)
  end

  # The form again, as typed, with each layer's options and the price —
  # nothing saved. acao: "nova" (an empty card) or "tirar-<card>-cima|baixo".
  # Usage: POST /construcoes/montar (the form's fields; construcao_uuid when editing)
  def montar
    @construcao = params[:construcao_uuid].present? ? construcao_por_uuid(params[:construcao_uuid]) : visiveis(Construcao).new
    aplicar_formulario(@construcao) unless @construcao.em_uso?
    preparar_montagem
    @problemas = RegrasDaConstrucao.new(@construcao).erros
    render turbo_stream: turbo_stream.replace("construcao-montagem", partial: "montagem")
  end

  def destroy
    construcao = construcao_por_uuid(params[:id])
    construcao.excluir!(**autoria)
    redirect_to construcoes_path, notice: "#{construcao.nome}: foi para a lixeira."
  end

  private

  def construcao_por_uuid(uuid)
    visiveis(Construcao).includes(camadas: %i[materia_prima ligante]).por_uuid!(uuid)
  end

  def aplicar_formulario(construcao)
    dados = params.require(:construcao)
    construcao.assign_attributes(situacao: dados[:situacao], client_uuid: dados[:client_uuid], preco_final: decimal_digitado(dados[:preco_final]))
    construcao.definir_camadas(MontagemDaChave.new(cards_do_formulario(dados), acao: params[:acao], materiais: visiveis(MateriaPrima)).camadas)
  end

  # The cards in the form's order; an unknown or blank material stays empty
  # for RegrasDaConstrucao to point out.
  def cards_do_formulario(dados)
    lado = %i[escolha do_cliente lado]
    # Not fetch(:dublagens, {}): Parameters#fetch turns the default into unpermitted params.
    permitidos = dados.permit(dublagens: [ :ligante_uuid, :posicao, { cima: lado, baixo: lado } ])[:dublagens]
    (permitidos || {}).to_h.sort_by { |indice, _| indice.to_i }.map(&:last)
  end

  def preparar_montagem
    @opcoes = OpcoesDaConstrucao.new(visiveis(MateriaPrima))
    @preco = PrecoSugeridoDaConstrucao.new(@construcao, servico: Empresa.atual&.preco_servico_dublagem)
    @clientes = visiveis(Client).ativos.order(:name)
    @grupos_de_ligante = grupos_de_ligante if pode_acao?(:editar_rede_de_dublagens)
  end

  # Dublagem 5b1b (Q1b): what "Adicionar à rede" offers — the groups the
  # network already joins with, and those of the registered ligantes.
  def grupos_de_ligante
    grupos = visiveis(GrupoMaterial)
    grupos.where(id: visiveis(LiganteDaLigacao).select(:grupo_material_id)).or(grupos.where(id: visiveis(MateriaPrima).ligantes.select(:grupo_material_id))).order(:nome)
  end

  def recusar(tela)
    preparar_montagem
    flash.now[:alert] = @construcao.errors.full_messages.to_sentence
    render tela, status: :unprocessable_content
  end
end
