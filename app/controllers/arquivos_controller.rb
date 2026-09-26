class ArquivosController < ApplicationController
  before_action :set_arquivo, only: %i[show update_time update_client update_modelo update_tamanho update_tipo_corte add_modelo remove_modelo preview composicao processamento download destroy upload_version approve_version version_preview configure_layers organize]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  PER_PAGE_GRID = 12
  PER_PAGE_LIST = 50

  def index
    load_gallery
    @arquivo = Arquivo.new
  end

  def show
    @time_logs = @arquivo.arquivo_time_logs.order(created_at: :desc)
    @versions = @arquivo.arquivo_versions.order(version_number: :desc)
    @arquivo_version = ArquivoVersion.new
    @vinculo_logs = @arquivo.vinculo_logs.includes(:peca, :pedido)
  end

  def create
    @arquivo = Arquivo.new(arquivo_params)

    unless file_uploaded?
      @arquivo.errors.add(:original_file, "select a file to upload")
      load_gallery
      return render :index, status: :unprocessable_content
    end

    estimate_time!(@arquivo) if params.dig(:arquivo, :batch_started_at).present?
    ArquivoUploadService.call(params[:arquivo][:original_file], remote_ip: request.remote_ip, arquivo: @arquivo)

    if @arquivo.persisted?
      redirect_to arquivos_path, notice: "Arquivo uploaded successfully. Processing started."
    else
      load_gallery
      render :index, status: :unprocessable_content
    end
  end

  def upload_version
    upload = params[:original_file]
    unless upload.respond_to?(:original_filename)
      return redirect_to @arquivo, alert: "Select a file to upload."
    end

    version_number = @arquivo.next_version_number
    version = @arquivo.arquivo_versions.build(
      version_number: version_number,
      uuid: SecureRandom.uuid,
      filename: File.basename(upload.original_filename, ".*"),
      extension: File.extname(upload.original_filename).delete(".").downcase,
      mime_type: upload.content_type,
      status: :pending,
      category: @arquivo.category
    )

    if ArquivoUploadService.erro_de_tipo(version.extension, upload)
      return redirect_to @arquivo, alert: "Invalid file type."
    end

    version.store_original!(upload)
    version.original_file = upload.original_filename

    version.save!

    @arquivo.arquivo_versions.where(approved: true).update_all(approved: false)
    version.update!(approved: true)
    @arquivo.update!(approved_version_id: version.id)

    ArquivoProcessingJob.perform_later(version.id)
    redirect_to @arquivo, notice: "Version #{version_number} uploaded and processing."
  end

  def approve_version
    version = @arquivo.arquivo_versions.find(params[:version_id])
    @arquivo.arquivo_versions.update_all(approved: false)
    version.update!(approved: true)
    @arquivo.update!(approved_version_id: version.id)
    redirect_to @arquivo, notice: "Version #{version.version_number} approved."
  end

  def configure_layers
    version = @arquivo.arquivo_versions.find(params[:version_id])
    annotations = params[:layer_annotations]
    unless annotations.is_a?(ActionController::Parameters) || annotations.is_a?(Hash)
      return head :bad_request
    end

    CutLayerConfigurationService.call(version, annotations)
    redirect_to @arquivo, notice: "Layer configuration saved."
  end

  def add_modelo
    modelo = Modelo.ativos.find(params[:modelo_id])
    if @arquivo.corte? && @arquivo.organized? && @arquivo.peca_id.present?
      conflict = Arquivo.conflicting_corte(peca_id: @arquivo.peca_id, modelo: modelo)
      if conflict && conflict.id != @arquivo.id
        flash.now[:alert] = "Peça \"#{@arquivo.peca.nome}\" já possui corte organizado para este modelo."
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @arquivo, alert: flash.now[:alert] }
        end
        return
      end
    end
    unless @arquivo.modelos.include?(modelo)
      @arquivo.modelos << modelo
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @arquivo, notice: "Modelo added." }
    end
  end

  def remove_modelo
    modelo = @arquivo.modelos.find(params[:modelo_id])
    @arquivo.modelos.delete(modelo)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @arquivo, notice: "Modelo removed." }
    end
  end

  def update_client
    if @arquivo.update(client_id: params[:client_id].presence)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Client updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update client: #{@arquivo.errors.full_messages.to_sentence}"
    end
  end

  def update_modelo
    updates = { modelo_id: params[:modelo_id].presence }
    updates[:molde_id] = params[:molde_id].presence if params[:molde_id].present?
    updates[:peca_id] = params[:peca_id].presence if params[:peca_id].present?

    if @arquivo.update(updates)
      @arquivo.reload
      TamanhoAutoAssignService.call(@arquivo)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Modelo updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update modelo: #{@arquivo.errors.full_messages.to_sentence}"
    end
  end

  def update_tamanho
    if @arquivo.update(tamanho_id: params[:tamanho_id].presence)
      @arquivo.reload
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Size updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update size: #{@arquivo.errors.full_messages.to_sentence}"
    end
  end

  def update_tipo_corte
    if @arquivo.update(tipo_corte: params[:tipo_corte])
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Cut type updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update cut type."
    end
  end

  def update_time
    previous_seconds = @arquivo.annotated_seconds || @arquivo.estimated_seconds
    new_seconds = parse_hmm(params[:annotated_seconds])

    if @arquivo.update(annotated_seconds: new_seconds)
      @arquivo.arquivo_time_logs.create!(
        previous_seconds: previous_seconds,
        new_seconds: @arquivo.annotated_seconds,
        changed_by: request.remote_ip
      )
      @time_logs = @arquivo.arquivo_time_logs.order(created_at: :desc)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Time updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update time."
    end
  end

  def preview
    path = @arquivo.preview_file
    raise ActionController::MissingFile unless path && File.exist?(path.to_s)

    mime = path.to_s.end_with?(".svg") ? "image/svg+xml" : "image/png"
    send_file path.to_s, type: mime, disposition: "inline"
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  # Pieces of this arte's modelo (see ModeloComposicaoService), for the
  # "Adicionar ao Pedido" modal to list before the item is created.
  # Usage: GET /arquivos/:uuid/composicao → { pecas: [{ peca_nome:, arquivo_uuid:, … }] }
  def composicao
    slots = ModeloComposicaoService.call(@arquivo)
    render json: { pecas: slots.map { |slot| composicao_slot_json(slot) } }
  end

  # Processing state of the approved version, polled by the "processamento"
  # Stimulus controller while an arquivo is queued. Safety net for a broadcast
  # sent while the page was still (re)connecting to the cable — it never
  # arrives, and the card stayed on "Processando" (Etapa 0.3, seen in E2E).
  # Usage: GET /arquivos/:uuid/processamento.json → { status:, final: }
  #        GET /arquivos/:uuid/processamento (turbo-stream) → replaces the card
  def processamento
    respond_to do |format|
      format.json { render json: { status: @arquivo.status, final: !(@arquivo.pending? || @arquivo.processing?) } }
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@arquivo, partial: "arquivos/card", locals: { arquivo: @arquivo }) }
    end
  end

  def version_preview
    version = @arquivo.arquivo_versions.find(params[:version_id])
    raise ActionController::MissingFile if version.preview_file.blank?
    path = version.preview_file
    raise ActionController::MissingFile unless File.exist?(path)
    mime = path.end_with?(".svg") ? "image/svg+xml" : "image/png"
    send_file path, type: mime, disposition: "inline"
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  def download
    path = @arquivo.approved_original_path
    raise ActionController::MissingFile unless path && File.exist?(path.to_s)
    version = @arquivo.approved_version
    filename = "#{version.filename}.#{version.extension}"
    send_file path.to_s, type: version.mime_type, disposition: "attachment", filename: filename
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  def organize
    update_attrs = { organized: true }
    update_attrs[:molde_id] = params[:molde_id].presence if params[:molde_id].present?
    update_attrs[:peca_id] = params[:peca_id].presence if params[:peca_id].present?
    update_attrs[:molde_nome] = params[:molde_nome].presence if params[:molde_nome].present?
    update_attrs[:peca_nome] = params[:peca_nome].presence if params[:peca_nome].present?

    peca_id = params[:peca_id].presence
    if peca_id && @arquivo.corte?
      conflicting = @arquivo.modelos.any? { |m|
        c = Arquivo.conflicting_corte(peca_id: peca_id, modelo: m)
        c && c.id != @arquivo.id
      }
      if conflicting
        flash.now[:alert] = "Esta peça já possui um corte organizado para este modelo."
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @arquivo, alert: flash.now[:alert] }
        end
        return
      end
    end

    unless @arquivo.update(update_attrs)
      flash.now[:alert] = @arquivo.errors.full_messages.join(", ")
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, alert: flash.now[:alert] }
      end
      return
    end

    TamanhoReplacementService.call(@arquivo, params[:tamanhos]) if params[:tamanhos].respond_to?(:values)

    if @arquivo.organize_error.present?
      DxfOrganizationService.call(@arquivo)
    elsif @arquivo.tamanhos.any? && @arquivo.tamanhos.all? { |t| t.preview_file.blank? }
      DxfOrganizationService.generate_tamanho_previews(@arquivo)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @arquivo, notice: "Mold organization saved." }
    end
  end

  # Etapa 0.4: goes to the trash; the row, its versions and the files in
  # storage/stamps/<uuid> stay, so pedidos that use it keep their previews
  # and it can be restored from /lixeira.
  def destroy
    @arquivo.excluir!(changed_by: request.remote_ip)
    redirect_to arquivos_path, notice: "Arquivo moved to the trash."
  end

  def batch_destroy
    ids = params[:ids]
    unless ids.is_a?(Array) && ids.any?
      return render json: { error: "No IDs provided" }, status: :unprocessable_content
    end

    destroyed_uuids, errors = ArquivoBatchDestroyService.call(ids, changed_by: request.remote_ip)

    render json: { destroyed: destroyed_uuids.size, errors: errors }
  end

  private

  def composicao_slot_json(slot)
    arte = slot.arquivo
    {
      peca_nome: slot.peca&.nome,
      arquivo_uuid: arte&.uuid,
      filename: arte&.filename,
      preview_url: arte&.preview_file.present? ? preview_arquivo_path(arte) : nil,
      pendente: arte.nil?,
      adicionada: arte == @arquivo
    }
  end

  def set_arquivo
    @arquivo = Arquivo.find_by!(uuid: params[:id])
  end

  STORAGE_BASE = ArquivoVersion::STORAGE_BASE

  def file_uploaded?
    upload = params[:arquivo][:original_file]
    upload.respond_to?(:tempfile) || upload.respond_to?(:original_filename)
  end

  def parse_hmm(value)
    return value.to_i unless value.to_s.include?(":")

    hours, minutes = value.to_s.split(":").map(&:to_i)
    (hours * 3600) + (minutes * 60)
  end

  def not_found
    render plain: "Not found", status: :not_found
  end

  def estimate_time!(arquivo)
    arquivo.estimated_seconds = UploadTimeEstimator.call(
      batch_started_at: Time.parse(params[:arquivo][:batch_started_at]),
      batch_size: params[:arquivo][:batch_size].to_i
    )
  end

  def arquivo_params
    params.require(:arquivo).permit(:filename, :extension, :mime_type)
  end

  def load_gallery
    @view = %w[grid list].include?(params[:view]) ? params[:view] : "grid"
    per_page = @view == "list" ? PER_PAGE_LIST : PER_PAGE_GRID
    @page = [ params[:page].to_i, 1 ].max

    base = Arquivo.ativos.includes(:client, :tamanhos, approved_version: :image_metadata, modelo: :molde).order(created_at: :desc)
    @total = base.count
    @total_pages = (@total.to_f / per_page).ceil
    @page = @page.clamp(1, [ @total_pages, 1 ].max)
    @arquivos = base.offset((@page - 1) * per_page).limit(per_page)
  end
end
