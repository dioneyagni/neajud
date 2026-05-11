class AbuseDetectionJob < ApplicationJob
  queue_as :default

  MAX_LARGE_FILES = 3
  LARGE_FILE_THRESHOLD = 500.megabytes
  BAN_DURATION = 1.hour

  def perform(ip_address:, file_size:)
    return unless file_size >= LARGE_FILE_THRESHOLD

    key = "abuse:#{ip_address}"
    count = Rails.cache.increment(key, 1, expires_in: BAN_DURATION)

    if count >= MAX_LARGE_FILES
      Ban.create!(
        ip_address: ip_address,
        reason: "Uploaded #{count} files >= #{LARGE_FILE_THRESHOLD / 1.megabyte}MB within #{BAN_DURATION / 1.minute}min",
        expires_at: BAN_DURATION.from_now
      )
      Rails.cache.delete(key)
      Rails.logger.warn "[AbuseDetection] Banned IP #{ip_address} for abuse"
    end
  end
end