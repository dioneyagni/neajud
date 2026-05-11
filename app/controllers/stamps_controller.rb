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

  def create
    @stamp = Stamp.new(stamp_params)

    if @stamp.save
      save_uploaded_file(@stamp)
      StampProcessingJob.perform_later(@stamp.id)
      redirect_to stamps_path, notice: "Stamp uploaded successfully. Processing started."
    else
      @stamps = Stamp.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def update_time
    previous_seconds = @stamp.annotated_seconds || @stamp.estimated_seconds

    if @stamp.update(annotated_seconds: params[:annotated_seconds])
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
    send_file path, type: "image/png", disposition: "inline"
  rescue Errno::ENOENT
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

  def not_found
    render plain: "Not found", status: :not_found
  end

  def stamp_params
    params.require(:stamp).permit(:original_file, :filename, :extension, :mime_type)
  end
end