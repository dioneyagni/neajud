class Arquivo < ApplicationRecord
  has_many :arquivo_time_logs, dependent: :destroy
  has_many :arquivo_versions
  has_many :tamanhos, dependent: :destroy
  has_many :arquivo_modelos, dependent: :destroy
  has_many :modelos, through: :arquivo_modelos
  belongs_to :approved_version, class_name: "ArquivoVersion", optional: true
  belongs_to :client, optional: true
  belongs_to :molde, optional: true
  belongs_to :peca, optional: true
  belongs_to :modelo, optional: true
  belongs_to :tamanho, optional: true

  before_validation :set_uuid, on: :create
  before_validation :set_default_tipo_corte
  after_update_commit :broadcast_arquivo_card, if: :saved_change_to_approved_version_id?
  before_destroy :destroy_arquivo_with_versions, prepend: true

  validates :uuid, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :category, inclusion: { in: FileCategory.keys }, allow_nil: true
  validates :tipo_corte, inclusion: { in: %w[apenas_corte corte_estampa] }, if: :corte?

  SUPPORTED_EXTENSIONS = FileCategory.extensions

  def corte?
    category == "corte"
  end

  def artes_vinculadas
    return Arquivo.none unless corte? && tipo_corte == "corte_estampa"
    Arquivo.where(category: "artes", tamanho_id: tamanhos.pluck(:id))
  end

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
    (arquivo_versions.maximum(:version_number) || 0) + 1
  end

  def approved_original_path
    approved_version&.original_path
  end

  private

  def set_default_tipo_corte
    self.tipo_corte ||= "corte_estampa" if corte?
  end

  def broadcast_arquivo_card
    broadcast_replace_to "arquivos", target: ActionView::RecordIdentifier.dom_id(self), partial: "arquivos/card", locals: { arquivo: self }
  end

  def destroy_arquivo_with_versions
    update_columns(approved_version_id: nil, tamanho_id: nil, client_id: nil, modelo_id: nil, molde_id: nil, peca_id: nil)
    arquivo_modelos.destroy_all
    arquivo_time_logs.destroy_all
    tamanhos.destroy_all
    arquivo_versions.each do |v|
      v.image_metadata&.destroy!
      v.cut_layers.destroy_all
      v.destroy!
    end
  end

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
