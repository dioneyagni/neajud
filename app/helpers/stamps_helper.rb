module StampsHelper
  def format_time(seconds)
    return "0:00" unless seconds

    hours = seconds / 3600
    mins = (seconds % 3600) / 60
    format("%d:%02d", hours, mins)
  end

  def stamp_preview_url(stamp)
    stamp_preview_path(stamp) if stamp.preview_file.present?
  end
end