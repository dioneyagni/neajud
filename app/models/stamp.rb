class Stamp < ApplicationRecord
  has_many :stamp_time_logs, dependent: :destroy
  has_many :stamp_versions
  belongs_to :approved_version, class_name: "StampVersion", optional: true

  before_validation :set_uuid, on: :create
  before_destroy :destroy_stamp_with_versions, prepend: true

  validates :uuid, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :category, inclusion: { in: FileCategory.keys }, allow_nil: true

  SUPPORTED_EXTENSIONS = FileCategory.extensions

  delegate :preview_file, :colorspace, :has_spots,
           :icc_profile, :width_px, :height_px, :dpi, :metadata,
           :category_notes, :colorspace_error,
           to: :approved_version, allow_nil: true, prefix: false

  STATUS_VALUES = %w[pending processing processed failed invalid_colorspace unsupported_format].freeze

  def self.statuses
    STATUS_VALUES.index_with(&:itself)
  end

  def status
    approved_version&.status
  end

  STATUS_VALUES.each do |name|
    define_method("#{name}?") do
      status == name
    end
  end

  def to_param
    uuid
  end

  def next_version_number
    (stamp_versions.maximum(:version_number) || 0) + 1
  end

  def approved_original_path
    approved_version&.original_path
  end

  private

  def destroy_stamp_with_versions
    update_column(:approved_version_id, nil)
    stamp_versions.each(&:destroy)
  end

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
