class StampVersion < ApplicationRecord
  belongs_to :stamp

  before_validation :set_uuid, on: :create

  validates :uuid, presence: true, uniqueness: true
  validates :version_number, presence: true, uniqueness: { scope: :stamp_id }
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :original_file, presence: true
  validates :status, presence: true

  scope :approved_first, -> { order(approved: :desc, version_number: :desc) }

  def to_param
    uuid
  end

  def storage_dir
    File.join(STORAGE_BASE, stamp.uuid, "v#{version_number}")
  end

  def original_path
    File.join(storage_dir, "original", original_file)
  end

  def preview_path
    return nil if preview_file.blank?
    preview_file
  end

  STORAGE_BASE = Rails.root.join("storage", "stamps")

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
