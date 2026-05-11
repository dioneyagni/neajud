class StampsController < ApplicationController
  before_action :set_stamp, only: %i[show update_time preview destroy]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    @stamps = Stamp.order(created_at: :desc)
    @stamp = Stamp.new
  end

  def show
    @time_logs = @stamp.stamp_time_logs.order(created_at: :desc)
  end

  MAX_FILE_SIZE = 1.gigabyte

  def create
    @stamp = Stamp.new(stamp_params)

    if validate_file_size! && validate_file_type! && @stamp.save
      save_uploaded_file(@stamp)
      StampProcessingJob.perform_now(@stamp.id)
      redirect_to stamps_path, notice: "Stamp uploaded successfully. Processing started."
    else
      @stamps = Stamp.order(created_at: :desc)
      render :index, status: :unprocessable_entity
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
    send_file path.to_s, type: "image/png", disposition: "inline"
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
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

  def save_uploaded_file(stamp)
    upload = params[:stamp][:original_file]
    return unless upload.respond_to?(:original_filename)

    ext = File.extname(upload.original_filename).delete(".").downcase
    dest_dir = File.join(STORAGE_BASE, stamp.uuid, "original")
    FileUtils.mkdir_p(dest_dir)
    dest_path = File.join(dest_dir, upload.original_filename)

    File.open(dest_path, "wb") { |f| f.write(upload.read) }
    stamp.update!(
      original_file: upload.original_filename,
      filename: File.basename(upload.original_filename, ".*"),
      extension: ext,
      mime_type: upload.content_type
    )
  end

  STORAGE_BASE = Rails.root.join("storage", "stamps")

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

  def validate_file_type!
    upload = params[:stamp][:original_file]
    return true unless upload.respond_to?(:tempfile)

    ext = params[:stamp][:extension].to_s.strip
    return true if ext.blank?

    validator = FileValidator.new(upload.tempfile.path)
    real_fmt = validator.real_format

    unless real_fmt
      @stamp.errors.add(:original_file, "unable to identify file format")
      return false
    end

    unless validator.valid_extension?(ext)
      @stamp.errors.add(:extension, "declared '#{ext.upcase}' but file is '#{real_fmt}'")
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

  def stamp_params
    params.require(:stamp).permit(:original_file, :filename, :extension, :mime_type)
  end
end