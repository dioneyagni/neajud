# The construções (Dublagem 3/5, decided 30/10-02/11/2026; plano Etapa 2.9
# D6/D7): the list, and the form of the dublagem canvas — the situação, the
# layers top to bottom with whose each is, a ligante between each two, the
# suggested price and the final one. Every change in the form asks `montar`
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
    @construcao.definir_camadas([ { lado: "trama" }, {} ])
    preparar_montagem
  end

  # Usage: POST /construcoes, construcao[situacao|client_uuid|preco_final],
  #        construcao[camadas][0][materia_prima_uuid|lado|do_cliente|ligante_uuid]
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
  # nothing saved. acao: "adicionar" a layer, or "remover-N".
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
    construcao.definir_camadas(camadas_com_acao(camadas_do_formulario(dados)))
  end

  # The layers in the form's order, each material looked up by uuid; an
  # unknown or blank one stays empty for RegrasDaConstrucao to point out.
  def camadas_do_formulario(dados)
    # Not fetch(:camadas, {}): Parameters#fetch turns the default into unpermitted params.
    permitidas = dados.permit(camadas: %i[materia_prima_uuid lado do_cliente ligante_uuid])[:camadas]
    linhas = (permitidas || {}).to_h.sort_by { |indice, _| indice.to_i }.map(&:last)
    linhas.map do |linha|
      { materia_prima: material_por_uuid(linha["materia_prima_uuid"]), lado: linha["lado"], do_cliente: linha["do_cliente"] == "1",
        ligante: material_por_uuid(linha["ligante_uuid"]) }
    end
  end

  def camadas_com_acao(camadas)
    acao = params[:acao].to_s
    return camadas + [ {} ] if acao == "adicionar" && camadas.size < Construcao::MAXIMO_DE_CAMADAS

    removida = acao.delete_prefix("remover-").to_i if acao.start_with?("remover-")
    removida && removida > 1 ? camadas.reject.with_index(1) { |_, posicao| posicao == removida } : camadas
  end

  def material_por_uuid(uuid)
    uuid.presence && visiveis(MateriaPrima).find_by(uuid: uuid)
  end

  def preparar_montagem
    @opcoes = OpcoesDaConstrucao.new(visiveis(MateriaPrima))
    @preco = PrecoSugeridoDaConstrucao.new(@construcao, servico: Empresa.atual&.preco_servico_dublagem)
    @clientes = visiveis(Client).ativos.order(:name)
  end

  def recusar(tela)
    preparar_montagem
    flash.now[:alert] = @construcao.errors.full_messages.to_sentence
    render tela, status: :unprocessable_content
  end
end
