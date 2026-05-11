class Stamp < ApplicationRecord
  has_many :stamp_time_logs, dependent: :destroy

  before_validation :set_uuid, on: :create

  enum :status, {
    pending: "pending",
    processing: "processing",
    processed: "processed",
    failed: "failed",
    invalid_colorspace: "invalid_colorspace",
    unsupported_format: "unsupported_format"
  }, default: :pending

  validates :uuid, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :status, presence: true

  SUPPORTED_EXTENSIONS = %w[tif tiff psd jpg jpeg ai eps cdr].freeze

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end