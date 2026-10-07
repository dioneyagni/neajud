# The files of an arte, one per part × size (Etapa 1.2, 2/3), from the arte
# page: add a file, bring other artes into this one, take a file out, choose
# each part's piloto, set a file's side (Etapa 1.2, 3/3 parte 3c).
class ArteArquivosController < ApplicationController
  before_action :set_arquivo
  before_action { exigir!(pode?(:artes, :editar), "artes: editar") }

  # voltar_para: a pedido's pendência sends the file from there (Etapa 1.2, 3/3).
  # Usage: POST /arquivos/:uuid/arte/acrescentar (original_file, tamanho_uuid | peca_uuid + tamanho_rotulo, lado, voltar_para)
  def acrescentar
    upload = params[:original_file]
    return redirect_to voltar_para, alert: "Choose the file to add." unless upload.respond_to?(:original_filename)
    return redirect_to voltar_para, alert: erro_de_categoria(upload) if erro_de_categoria(upload)

    novo = ArquivoUploadService.call(upload, remote_ip: request.remote_ip, arquivo: novo_arquivo_da_arte)
    return redirect_to voltar_para, alert: "Could not add #{upload.original_filename}: #{novo.errors.full_messages.to_sentence}" unless novo.persisted?

    redirect_to voltar_para, notice: "#{novo.filename} added to this arte#{" (#{novo.rotulo_de_tamanho})" if novo.rotulo_de_tamanho}."
  end

  # Brings the marked artes into this one (decided 05/10/2026: from the P's
  # page, mark the M and the G). All are checked before any moves, so a
  # refused one leaves everything as it was.
  # Usage: POST /arquivos/:uuid/arte/trazer (origem_uuids[])
  def trazer
    origens = Arquivo.ativos.where(uuid: Array(params[:origem_uuids])).to_a
    return redirect_to @arquivo, alert: "Mark the artes to bring into this one." if origens.empty?

    erros = origens.filter_map { |origem| JuntarArtesService.erro(origem: origem, destino: @arquivo) }
    return redirect_to @arquivo, alert: "Nothing was joined: #{erros.to_sentence}" if erros.any?

    origens.each { |origem| JuntarArtesService.call(origem: origem, destino: @arquivo) }
    redirect_to @arquivo, notice: "Joined into this arte: #{origens.map(&:filename).to_sentence}."
  end

  # Usage: POST /arquivos/:uuid/arte/separar
  def separar
    @arquivo.separar_da_arte!
    redirect_to @arquivo, notice: "#{@arquivo.filename} is now an arte of its own."
  rescue ArgumentError => e
    redirect_to @arquivo, alert: e.message
  end

  # Makes this file its part's piloto (Etapa 1.2, 2/3 parte 2b). junto_de: a
  # file of the arte it belongs to — from the "same arte uploaded again"
  # offer, when the piloto was uploaded as another arte, that arte joins first.
  # Usage: POST /arquivos/:uuid/arte/tornar_piloto (junto_de)
  def tornar_piloto
    destino = Arquivo.ativos.por_uuid!(params[:junto_de]) if params[:junto_de].present?
    JuntarArtesService.call(origem: @arquivo, destino: destino) if destino && destino.arte_id != @arquivo.arte_id
    anterior = @arquivo.reload.tornar_piloto!
    redirect_to destino || @arquivo, notice: "#{@arquivo.filename} is now the piloto of #{@arquivo.resolved_peca&.nome || "its part"}#{" (#{anterior.filename} went back to production)" if anterior}."
  rescue JuntarArtesService::Recusado, ActiveRecord::RecordInvalid => e
    redirect_to destino || @arquivo, alert: e.message
  end

  # Usage: POST /arquivos/:uuid/arte/voltar_para_producao
  def voltar_para_producao
    @arquivo.voltar_para_producao!
    redirect_to @arquivo, notice: "#{@arquivo.filename} is a production file again."
  end

  # The side of a file of a mirrored part; blank = no side (serves both).
  # Usage: PATCH /arquivos/:uuid/arte/definir_lado (lado: "esquerdo")
  def definir_lado
    if @arquivo.update(lado: params[:lado].presence)
      redirect_to voltar_para, notice: "#{@arquivo.filename}: #{@arquivo.lado ? "side #{@arquivo.lado_abreviado}" : "no side (serves both)"}."
    else
      redirect_to voltar_para, alert: @arquivo.errors.full_messages.to_sentence
    end
  end

  private

  # Only paths of this app (url_from refuses other hosts), else the arte page.
  def voltar_para
    url_from(params[:voltar_para]) || arquivo_path(@arquivo)
  end

  def set_arquivo
    @arquivo = Arquivo.ativos.where.not(category: "corte").por_uuid!(params[:arquivo_id])
  end

  def erro_de_categoria(upload)
    extensao = File.extname(upload.original_filename).delete(".").downcase
    return nil if FileCategory.for_extension(extensao) == "artes"

    "#{upload.original_filename} is not an arte file; expected one of #{FileCategory.all["artes"][:extensions].join(", ")}"
  end

  # The new file shares the arte's fields; its size comes from the molde's
  # cortes when the arte has a molde, else from what was typed.
  def novo_arquivo_da_arte
    novo = @arquivo.arte.novo_arquivo
    novo.lado = params[:lado].presence
    tamanho = tamanho_escolhido
    return com_tamanho_do_corte(novo, tamanho) if tamanho

    novo.peca = Peca.ativos.por_uuid!(params[:peca_uuid]) if params[:peca_uuid].present?
    novo.tamanho_rotulo = params[:tamanho_rotulo].to_s.squish.presence
    novo
  end

  def com_tamanho_do_corte(novo, tamanho)
    novo.tamanho = tamanho
    novo.tamanho_rotulo = tamanho.nome
    novo
  end

  def tamanho_escolhido
    return nil if params[:tamanho_uuid].blank? || @arquivo.molde.nil?

    Tamanho.unscoped.where(arquivo_id: Arquivo.cortes_do_molde(@arquivo.molde).select(:id)).por_uuid!(params[:tamanho_uuid])
  end
end
