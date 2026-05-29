class ArquivoVersion < ApplicationRecord
  belongs_to :arquivo

  has_one :image_metadata, class_name: "ArquivoImageMetadata", dependent: :destroy
  has_many :cut_layers, dependent: :destroy

  before_validation :set_uuid, on: :create

  validates :uuid, presence: true, uniqueness: true
  validates :version_number, presence: true, uniqueness: { scope: :arquivo_id }
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
    File.join(STORAGE_BASE, arquivo.uuid, "v#{version_number}")
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
