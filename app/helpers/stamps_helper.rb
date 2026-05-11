module StampsHelper
  def format_time(seconds)
    return "0:00" unless seconds

    hours = seconds / 3600
    mins = (seconds % 3600) / 60
    format("%d:%02d", hours, mins)
  end

  def preview_stamp_url(stamp)
    preview_stamp_path(stamp) if stamp.preview_file.present?
  end
end