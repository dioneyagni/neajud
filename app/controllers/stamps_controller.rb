class StampsController < ApplicationController
  before_action :set_stamp, only: %i[show update_time update_client preview download destroy upload_version approve_version version_preview configure_layers organize]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    @stamps = Stamp.includes(:approved_version).order(created_at: :desc)
    @stamp = Stamp.new
  end

  def show
    @time_logs = @stamp.stamp_time_logs.order(created_at: :desc)
    @versions = @stamp.stamp_versions.order(version_number: :desc)
    @stamp_version = StampVersion.new
  end

  MAX_FILE_SIZE = 1.gigabyte

  def create
    @stamp = Stamp.new(stamp_params)
    @stamps = Stamp.order(created_at: :desc)

    unless file_uploaded?
      @stamp.errors.add(:original_file, "select a file to upload")
      return render :index, status: :unprocessable_content
    end

    extract_file_metadata!(@stamp)
    estimate_time!(@stamp) if params.dig(:stamp, :batch_started_at).present?

    if validate_file_size! && validate_file_type! && @stamp.save
      upload = params[:stamp][:original_file]
      version = create_and_save_version!(@stamp, upload)
      StampProcessingJob.perform_now(version.id)
      redirect_to stamps_path, notice: "Stamp uploaded successfully. Processing started."
    else
      render :index, status: :unprocessable_content
    end
  end

  def upload_version
    upload = params[:original_file]
    unless upload.respond_to?(:original_filename)
      return redirect_to @stamp, alert: "Select a file to upload."
    end

    version_number = @stamp.next_version_number
    version = @stamp.stamp_versions.build(
      version_number: version_number,
      uuid: SecureRandom.uuid,
      filename: File.basename(upload.original_filename, ".*"),
      extension: File.extname(upload.original_filename).delete(".").downcase,
      mime_type: upload.content_type,
      status: :pending,
      category: @stamp.category
    )

    unless validate_file_type!(version, upload)
      return redirect_to @stamp, alert: "Invalid file type."
    end

    FileUtils.mkdir_p(version.storage_dir)
    dest_dir = File.join(version.storage_dir, "original")
    FileUtils.mkdir_p(dest_dir)
    dest_path = File.join(dest_dir, upload.original_filename)
    File.open(dest_path, "wb") { |f| f.write(upload.read) }
    version.original_file = upload.original_filename

    version.save!

    @stamp.stamp_versions.where(approved: true).update_all(approved: false)
    version.update!(approved: true)
    @stamp.update!(approved_version_id: version.id)

    StampProcessingJob.perform_now(version.id)
    redirect_to @stamp, notice: "Version #{version_number} uploaded and processing."
  end

  def approve_version
    version = @stamp.stamp_versions.find(params[:version_id])
    @stamp.stamp_versions.update_all(approved: false)
    version.update!(approved: true)
    @stamp.update!(approved_version_id: version.id)
    redirect_to @stamp, notice: "Version #{version.version_number} approved."
  end

  def configure_layers
    version = @stamp.stamp_versions.find(params[:version_id])
    annotations = params[:layer_annotations]
    raise "Invalid layer_annotations" unless annotations.is_a?(ActionController::Parameters) || annotations.is_a?(Hash)

    existing = version.cut_layers.index_by(&:color)
    version.cut_layers.destroy_all
    annotations.values.map(&:permit!).map(&:to_h).each_with_index do |layer, idx|
      prev = existing[layer["color"]]
      version.cut_layers.create!(
        layer_name: layer["layer_name"],
        color: layer["color"],
        annotation: layer["annotation"] || "cut",
        position: idx,
        width_mm: prev&.width_mm,
        height_mm: prev&.height_mm,
        perimeter_mm: prev&.perimeter_mm,
        area_mm2: prev&.area_mm2
      )
    end
    if @stamp.extension.downcase == "dxf" && @stamp.organize_error.present?
      DxfOrganizationService.call(@stamp)
    end
    redirect_to @stamp, notice: "Layer configuration saved."
  end

  def update_client
    if @stamp.update(client_id: params[:client_id].presence)
      redirect_to @stamp, notice: "Client updated."
    else
      redirect_to @stamp, alert: "Could not update client."
    end
  end

  def update_time
    previous_seconds = @stamp.annotated_seconds || @stamp.estimated_seconds
    new_seconds = parse_hmm(params[:annotated_seconds])

    if @stamp.update(annotated_seconds: new_seconds)
      @stamp.stamp_time_logs.create!(
        previous_seconds: previous_seconds,
        new_seconds: @stamp.annotated_seconds,
        changed_by: request.remote_ip
      )
      redirect_to @stamp, notice: "Time updated."
    else
      redirect_to @stamp, alert: "Could not update time."
    end
  end

  def preview
    path = @stamp.preview_file
    raise ActionController::MissingFile unless path && File.exist?(path.to_s)

    mime = path.to_s.end_with?(".svg") ? "image/svg+xml" : "image/png"
    send_file path.to_s, type: mime, disposition: "inline"
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  def version_preview
    version = @stamp.stamp_versions.find(params[:version_id])
    raise ActionController::MissingFile if version.preview_file.blank?
    path = version.preview_file
    raise ActionController::MissingFile unless File.exist?(path)
    mime = path.end_with?(".svg") ? "image/svg+xml" : "image/png"
    send_file path, type: mime, disposition: "inline"
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  def download
    path = @stamp.approved_original_path
    raise ActionController::MissingFile unless path && File.exist?(path.to_s)
    version = @stamp.approved_version
    filename = "#{version.filename}.#{version.extension}"
    send_file path.to_s, type: version.mime_type, disposition: "attachment", filename: filename
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  def organize
    @stamp.update!(
      molde_nome: params[:molde_nome].presence || @stamp.molde_nome,
      peca_nome: params[:peca_nome].presence || @stamp.peca_nome,
      organized: true
    )
    if params[:tamanhos].respond_to?(:values)
      @stamp.tamanhos.destroy_all
      tamanhos = params[:tamanhos].is_a?(ActionController::Parameters) ? params[:tamanhos].to_unsafe_h : params[:tamanhos]
      tamanhos.sort_by { |k, _| k.to_i }.each_with_index do |(_, t), idx|
        @stamp.tamanhos.create!(
          nome: t["nome"].presence || "Size #{idx + 1}",
          position: idx + 1,
          width_mm: t["width_mm"],
          height_mm: t["height_mm"],
          area_mm2: t["area_mm2"]
        )
      end
    end

    if @stamp.organize_error.present?
      DxfOrganizationService.call(@stamp)
    end

    redirect_to @stamp, notice: "Mold organization saved."
  end

  def destroy
    FileUtils.rm_rf(File.join(STORAGE_BASE, @stamp.uuid))
    @stamp.destroy!
    redirect_to stamps_path, notice: "Stamp deleted."
  end

  private

  def set_stamp
    @stamp = Stamp.find_by!(uuid: params[:id])
  end

  def create_and_save_version!(stamp, upload)
    version = stamp.stamp_versions.create!(
      version_number: 1,
      uuid: SecureRandom.uuid,
      filename: stamp.filename,
      extension: stamp.extension,
      mime_type: stamp.mime_type,
      original_file: upload.original_filename,
      status: :pending,
      approved: true,
      category: stamp.category,
      category_notes: stamp.category_notes
    )
    stamp.update!(approved_version_id: version.id)

    dest_dir = File.join(version.storage_dir, "original")
    FileUtils.mkdir_p(dest_dir)
    dest_path = File.join(dest_dir, upload.original_filename)
    File.open(dest_path, "wb") { |f| f.write(upload.read) }

    stamp.update!(
      filename: File.basename(upload.original_filename, ".*"),
      extension: File.extname(upload.original_filename).delete(".").downcase,
      mime_type: upload.content_type
    )

    version
  end

  STORAGE_BASE = Rails.root.join("storage", "stamps")

  def file_uploaded?
    upload = params[:stamp][:original_file]
    upload.respond_to?(:tempfile) || upload.respond_to?(:original_filename)
  end

  def extract_file_metadata!(stamp)
    upload = params[:stamp][:original_file]
    return unless upload.respond_to?(:original_filename)

    stamp.filename = File.basename(upload.original_filename, ".*") if stamp.filename.blank?
    stamp.extension = File.extname(upload.original_filename).delete(".").downcase if stamp.extension.blank?
    stamp.mime_type = upload.content_type if stamp.mime_type.blank?

    stamp.category = FileCategory.for_extension(stamp.extension) if stamp.category.blank?
    stamp.category_notes = FileCategory.notes(stamp.extension, stamp.category) if stamp.category_notes.blank?
  end

  def validate_file_size!
    upload = params[:stamp][:original_file]
    return true unless upload.respond_to?(:tempfile)

    real_size = upload.tempfile.size
    if real_size > MAX_FILE_SIZE
      @stamp.errors.add(:original_file, "exceeds maximum size of 1GB")
      AbuseDetectionJob.perform_later(ip_address: request.remote_ip, file_size: real_size)
      return false
    end
    true
  end

  def validate_file_type!(record = nil, upload = nil)
    record ||= @stamp
    upload ||= params[:stamp][:original_file]
    return true unless upload.respond_to?(:tempfile)

    ext = record.extension.to_s.strip
    return true if ext.blank?

    return true if FileValidator::UNVERIFIABLE_EXTENSIONS.include?(ext)

    validator = FileValidator.new(upload.tempfile.path)
    real_fmt = validator.real_format

    unless real_fmt
      @stamp&.errors&.add(:original_file, "unable to identify file format")
      return false
    end

    unless validator.valid_extension?(ext)
      @stamp&.errors&.add(:extension, "declared '#{ext.upcase}' but file is '#{real_fmt}'")
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

  def estimate_time!(stamp)
    batch_started_at = Time.parse(params[:stamp][:batch_started_at])
    batch_size = params[:stamp][:batch_size].to_i
    last_stamp_time = Stamp.where("created_at < ?", batch_started_at).maximum(:created_at)

    if last_stamp_time
      interval = (batch_started_at - last_stamp_time).to_i
      stamp.estimated_seconds = [ interval / batch_size, 0 ].max
    else
      stamp.estimated_seconds = 0
    end
  end

  def stamp_params
    params.require(:stamp).permit(:filename, :extension, :mime_type)
  end
end
