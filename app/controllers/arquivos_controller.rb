class ArquivosController < ApplicationController
  before_action :set_arquivo, only: %i[show update_time update_client update_modelo update_tamanho update_tipo_corte add_modelo remove_modelo preview download destroy upload_version approve_version version_preview configure_layers organize]
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
  end

  MAX_FILE_SIZE = 1.gigabyte

  def create
    @arquivo = Arquivo.new(arquivo_params)

    unless file_uploaded?
      @arquivo.errors.add(:original_file, "select a file to upload")
      load_gallery
      return render :index, status: :unprocessable_content
    end

    extract_file_metadata!(@arquivo)
    estimate_time!(@arquivo) if params.dig(:arquivo, :batch_started_at).present?

    if validate_file_size! && validate_file_type! && @arquivo.save
      upload = params[:arquivo][:original_file]
      version = create_and_save_version!(@arquivo, upload)
      ArquivoProcessingJob.perform_now(version.id)
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

    unless validate_file_type!(version, upload)
      return redirect_to @arquivo, alert: "Invalid file type."
    end

    version.store_original!(upload)
    version.original_file = upload.original_filename

    version.save!

    @arquivo.arquivo_versions.where(approved: true).update_all(approved: false)
    version.update!(approved: true)
    @arquivo.update!(approved_version_id: version.id)

    ArquivoProcessingJob.perform_now(version.id)
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
    modelo = Modelo.find(params[:modelo_id])
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
      redirect_to @arquivo, alert: "Could not update client."
    end
  end

  def update_modelo
    updates = { modelo_id: params[:modelo_id].presence }
    updates[:molde_id] = params[:molde_id].presence if params[:molde_id].present?
    updates[:peca_id] = params[:peca_id].presence if params[:peca_id].present?

    if @arquivo.update(updates)
      @arquivo.reload
      unless @arquivo.tamanho_id
        matched_tamanho = MoldMatchService.call(@arquivo)
        if matched_tamanho
          @arquivo.update(tamanho_id: matched_tamanho.id)
          corte = matched_tamanho.arquivo
          if corte && corte.molde_id != @arquivo.molde_id
            @arquivo.update_column(:molde_id, corte.molde_id)
            @arquivo.reload
          end
        else
          corte = @arquivo.corte_via_modelo
          primeiro_tamanho = corte&.tamanhos&.first
          @arquivo.update(tamanho_id: primeiro_tamanho.id) if primeiro_tamanho
        end
      end
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Modelo updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update modelo."
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
      redirect_to @arquivo, alert: "Could not update size."
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

    if params[:tamanhos].respond_to?(:values)
      old_previews = @arquivo.tamanhos.each_with_object({}) { |t, h| h[t.position] = t.preview_file }
      tamanho_ids = @arquivo.tamanhos.pluck(:id)
      Arquivo.where(tamanho_id: tamanho_ids).update_all(tamanho_id: nil)
      @arquivo.tamanhos.destroy_all
      raw = params[:tamanhos].is_a?(ActionController::Parameters) ? params[:tamanhos].to_unsafe_h : params[:tamanhos]
      tamanhos = raw.transform_values { |v|
        v.is_a?(Hash) ? v.slice("nome", "position", "width_mm", "height_mm", "area_mm2") : v
      }
      tamanhos.sort_by { |k, _| k.to_i }.each_with_index do |(_, t), idx|
        pos = idx + 1
        preview = old_previews[pos]
        @arquivo.tamanhos.create!(
          nome: t["nome"].presence || "Size #{idx + 1}",
          position: pos,
          width_mm: t["width_mm"],
          height_mm: t["height_mm"],
          area_mm2: t["area_mm2"],
          preview_file: preview
        )
      end
    end

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

  def destroy
    # destroy (not destroy!) so a blocked deletion (e.g. an arte still linked
    # to this corte's tamanho, see Arquivo#prevent_destroy_with_linked_arquivos)
    # comes back as a normal flash instead of an unhandled 500. Removing the
    # upload folder only after a successful destroy avoids deleting real
    # files for a row that turned out not to be destroyable.
    unless @arquivo.destroy
      redirect_to @arquivo, alert: @arquivo.errors[:base].to_sentence
      return
    end
    FileUtils.rm_rf(File.join(STORAGE_BASE, @arquivo.uuid))
    redirect_to arquivos_path, notice: "Arquivo deleted."
  end

  def batch_destroy
    ids = params[:ids]
    unless ids.is_a?(Array) && ids.any?
      return render json: { error: "No IDs provided" }, status: :unprocessable_content
    end

    destroyed_uuids, errors = destroy_arquivos_batch(ids)
    destroyed_uuids.each { |uuid| FileUtils.rm_rf(File.join(STORAGE_BASE, uuid)) }

    render json: { destroyed: destroyed_uuids.size, errors: errors }
  end

  private

  def set_arquivo
    @arquivo = Arquivo.find_by!(uuid: params[:id])
  end

  # Bug fix: this used to wrap every id in ONE transaction and roll the
  # whole thing back on the first failure, yet still reported the
  # already-rolled-back items as destroyed (destroyed/errors were plain Ruby
  # counters, unaffected by the DB rollback). Destroying each arquivo in its
  # own (implicit) transaction makes one bad id fail on its own without
  # undoing the others, and the returned uuids are only ever ones that
  # actually committed. Also never removed storage/stamps/:uuid — callers
  # now do that themselves for each returned uuid.
  def destroy_arquivos_batch(ids)
    destroyed_uuids = []
    errors = []
    ids.each do |uuid|
      arquivo = Arquivo.find_by(uuid: uuid)
      next errors << uuid unless arquivo

      if arquivo.destroy
        destroyed_uuids << uuid
      else
        errors << { uuid: uuid, error: arquivo.errors[:base].to_sentence.presence || "could not be deleted" }
      end
    end
    [ destroyed_uuids, errors ]
  end

  def create_and_save_version!(arquivo, upload)
    version = arquivo.arquivo_versions.create!(
      version_number: 1,
      uuid: SecureRandom.uuid,
      filename: arquivo.filename,
      extension: arquivo.extension,
      mime_type: arquivo.mime_type,
      original_file: upload.original_filename,
      status: :pending,
      approved: true,
      category: arquivo.category,
      category_notes: arquivo.category_notes
    )
    arquivo.update!(approved_version_id: version.id)
    version.store_original!(upload)

    arquivo.update!(
      filename: File.basename(upload.original_filename, ".*"),
      extension: File.extname(upload.original_filename).delete(".").downcase,
      mime_type: upload.content_type
    )

    version
  end

  STORAGE_BASE = ArquivoVersion::STORAGE_BASE

  def file_uploaded?
    upload = params[:arquivo][:original_file]
    upload.respond_to?(:tempfile) || upload.respond_to?(:original_filename)
  end

  def extract_file_metadata!(arquivo)
    upload = params[:arquivo][:original_file]
    return unless upload.respond_to?(:original_filename)

    arquivo.filename = File.basename(upload.original_filename, ".*") if arquivo.filename.blank?
    arquivo.extension = File.extname(upload.original_filename).delete(".").downcase if arquivo.extension.blank?
    arquivo.mime_type = upload.content_type if arquivo.mime_type.blank?

    arquivo.category = FileCategory.for_extension(arquivo.extension) if arquivo.category.blank?
    arquivo.category_notes = FileCategory.notes(arquivo.extension, arquivo.category) if arquivo.category_notes.blank?
  end

  def validate_file_size!
    upload = params[:arquivo][:original_file]
    return true unless upload.respond_to?(:tempfile)

    real_size = upload.tempfile.size
    if real_size > MAX_FILE_SIZE
      @arquivo.errors.add(:original_file, "exceeds maximum size of 1GB")
      AbuseDetectionJob.perform_later(ip_address: request.remote_ip, file_size: real_size)
      return false
    end
    true
  end

  def validate_file_type!(record = nil, upload = nil)
    record ||= @arquivo
    upload ||= params[:arquivo][:original_file]
    return true unless upload.respond_to?(:tempfile)

    ext = record.extension.to_s.strip
    return true if ext.blank?

    return true if FileValidator::UNVERIFIABLE_EXTENSIONS.include?(ext)

    validator = FileValidator.new(upload.tempfile.path)
    real_fmt = validator.real_format

    unless real_fmt
      @arquivo&.errors&.add(:original_file, "unable to identify file format")
      return false
    end

    unless validator.valid_extension?(ext)
      @arquivo&.errors&.add(:extension, "declared '#{ext.upcase}' but file is '#{real_fmt}'")
      return false
    end

    true
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
    batch_started_at = Time.parse(params[:arquivo][:batch_started_at])
    batch_size = params[:arquivo][:batch_size].to_i
    last_arquivo_time = Arquivo.where("created_at < ?", batch_started_at).maximum(:created_at)

    if last_arquivo_time
      interval = (batch_started_at - last_arquivo_time).to_i
      arquivo.estimated_seconds = [ interval / batch_size, 0 ].max
    else
      arquivo.estimated_seconds = 0
    end
  end

  def arquivo_params
    params.require(:arquivo).permit(:filename, :extension, :mime_type)
  end

  def load_gallery
    @view = %w[grid list].include?(params[:view]) ? params[:view] : "grid"
    per_page = @view == "list" ? PER_PAGE_LIST : PER_PAGE_GRID
    @page = [ params[:page].to_i, 1 ].max

    base = Arquivo.includes(:client, :tamanhos, approved_version: :image_metadata, modelo: :molde).order(created_at: :desc)
    @total = base.count
    @total_pages = (@total.to_f / per_page).ceil
    @page = @page.clamp(1, [ @total_pages, 1 ].max)
    @arquivos = base.offset((@page - 1) * per_page).limit(per_page)
  end
end
