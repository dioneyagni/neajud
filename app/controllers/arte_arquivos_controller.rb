# The files of an arte, one per part × size (Etapa 1.2, 2/3), from the arte
# page: add a file, join this arte into another, take a file out.
class ArteArquivosController < ApplicationController
  before_action :set_arquivo
  before_action { exigir!(pode?(:artes, :editar), "artes: editar") }

  # Usage: POST /arquivos/:uuid/arte/acrescentar (original_file, tamanho_uuid | peca_uuid + tamanho_rotulo)
  def acrescentar
    upload = params[:original_file]
    return redirect_to @arquivo, alert: "Choose the file to add." unless upload.respond_to?(:original_filename)
    return redirect_to @arquivo, alert: erro_de_categoria(upload) if erro_de_categoria(upload)

    novo = ArquivoUploadService.call(upload, remote_ip: request.remote_ip, arquivo: novo_arquivo_da_arte)
    return redirect_to @arquivo, alert: "Could not add #{upload.original_filename}: #{novo.errors.full_messages.to_sentence}" unless novo.persisted?

    redirect_to @arquivo, notice: "#{novo.filename} added to this arte#{" (#{novo.rotulo_de_tamanho})" if novo.rotulo_de_tamanho}."
  end

  # Usage: POST /arquivos/:uuid/arte/juntar (destino_uuid)
  def juntar
    destino = Arquivo.ativos.por_uuid!(params[:destino_uuid])
    JuntarArtesService.call(origem: @arquivo, destino: destino)
    redirect_to destino, notice: "Joined: #{@arquivo.filename} is now a file of #{destino.arte.titulo}."
  rescue JuntarArtesService::Recusado => e
    redirect_to @arquivo, alert: e.message
  end

  # Usage: POST /arquivos/:uuid/arte/separar
  def separar
    @arquivo.separar_da_arte!
    redirect_to @arquivo, notice: "#{@arquivo.filename} is now an arte of its own."
  rescue ArgumentError => e
    redirect_to @arquivo, alert: e.message
  end

  private

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
    novo = Arquivo.new(arte: @arquivo.arte, **@arquivo.attributes.slice(*MembroDeArte::CAMPOS_DA_ARTE).symbolize_keys)
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
