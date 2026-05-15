class Stamp < ApplicationRecord
  has_many :stamp_time_logs, dependent: :destroy
  has_many :stamp_versions
  has_many :tamanhos, dependent: :destroy
  belongs_to :approved_version, class_name: "StampVersion", optional: true

  before_validation :set_uuid, on: :create
  after_update_commit :broadcast_stamp_card, if: :saved_change_to_approved_version_id?
  before_destroy :destroy_stamp_with_versions, prepend: true

  validates :uuid, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :category, inclusion: { in: FileCategory.keys }, allow_nil: true

  SUPPORTED_EXTENSIONS = FileCategory.extensions

  attribute :molde_nome, :string, default: "New Mold"
  attribute :peca_nome, :string, default: "New Piece"
  delegate :preview_file, :category_notes,
           to: :approved_version, allow_nil: true, prefix: false

  %i[colorspace colorspace_error has_spots icc_profile width_px height_px dpi metadata].each do |attr|
    define_method(attr) do
      approved_version&.image_metadata&.public_send(attr)
    end
  end

  def has_spots?
    has_spots
  end

  def detected_program
    metadata&.dig("source_program")
  end

  def program_icon
    FileCategory.program_icon(extension, detected_program: detected_program)
  end

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

  def broadcast_stamp_card
    broadcast_replace_to "stamps", target: ActionView::RecordIdentifier.dom_id(self), partial: "stamps/stamp_card", locals: { stamp: self }
  end

  def destroy_stamp_with_versions
    update_column(:approved_version_id, nil)
    stamp_versions.each(&:destroy)
  end

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
