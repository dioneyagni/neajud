class ArquivoVersion < ApplicationRecord
  include GeraUuid
  belongs_to :arquivo

  has_one :image_metadata, class_name: "ArquivoImageMetadata", dependent: :destroy
  has_many :cut_layers, dependent: :destroy

  # Processing runs in Solid Queue (Etapa 0.3): open pages learn about each
  # status change (pending → processing → processed/failed) by broadcast.
  # reload: the job's arquivo caches its approved_version as another object
  # than this one, so it still read "processing" and the final card/refresh
  # never went out.
  after_update_commit -> { arquivo.reload.broadcast_status_change }, if: :saved_change_to_status?
  # Etapa 2.5b: a cor lisa's version is measured once processed.
  after_update_commit -> { MedirCorJob.perform_later(id) }, if: -> { saved_change_to_status? && status == "processed" && arquivo.arte&.tipo == "cor_lisa" }
  # Etapa 2.6b1: a DTF size's fit on the film follows its measure.
  after_update_commit -> { EncaixeDaEtiqueta.atualizar!(arquivo.reload) }, if: -> { saved_change_to_status? && status == "processed" && arquivo.arte&.tipo == "dtf" }

  validates :version_number, presence: true, uniqueness: { scope: :arquivo_id }
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :original_file, presence: true
  validates :status, presence: true

  scope :approved_first, -> { order(approved: :desc, version_number: :desc) }

  # The measured color of a cor lisa's version (Etapa 2.5b), nil until measured.
  # Usage: version.lab # => [54.3, 64.7, 55.3]
  def lab
    [ lab_l, lab_a, lab_b ] if lab_l
  end

  def storage_dir
    File.join(STORAGE_BASE, arquivo.uuid, "v#{version_number}")
  end

  def original_path
    File.join(storage_dir, "original", original_file)
  end

  # Writes an uploaded file to original/ under this version's storage dir.
  # Works before save: storage_dir only needs arquivo.uuid + version_number.
  # Usage: version.store_original!(params[:original_file])
  def store_original!(upload)
    dir = File.join(storage_dir, "original")
    FileUtils.mkdir_p(dir)
    File.binwrite(File.join(dir, upload.original_filename), upload.read)
  end

  def preview_path
    return nil if preview_file.blank?
    preview_file
  end

  # Separate physical directories per environment: storage/stamps holds real
  # development/production uploads; storage/test_stamps holds only
  # RSpec/E2E throwaway uploads, freely wiped by bin/e2e. Sharing a single
  # directory used to mean bin/e2e's `rm -rf storage/stamps/*` (needed so
  # E2E runs never accumulate test uploads) also destroyed real development
  # uploads on every run — the Arquivo rows survived (only the *test*
  # database gets truncated) but their files didn't, so previews silently
  # stopped rendering for anything uploaded before the next `bin/e2e` run.
  STORAGE_BASE = Rails.root.join("storage", Rails.env.test? ? "test_stamps" : "stamps")

  # Meters of a paper roll of this width one printed piece takes (Etapa 2.2,
  # 1/3; decided 07/10/2026): the file is a rectangle (pixels ÷ DPI), its
  # width across the roll and its height along it. A calçado arte never turns
  # (it must match its piece); girar: lets a later type (DTF) try 90° too.
  # A straight sum, nothing to store. nil without size/DPI or wider than the roll.
  # Usage: version.metros_por_peca(1600) # => 0.0215 (3 across, 64.5 mm tall)
  def metros_por_peca(largura_mm, girar: false)
    lados = medidas_mm
    return nil unless lados

    orientacoes = girar ? [ lados, lados.reverse ] : [ lados ]
    opcoes = orientacoes.filter_map do |largura, altura|
      lado_a_lado = (largura_mm / largura).floor
      altura / lado_a_lado / 1000.0 if lado_a_lado.positive?
    end
    opcoes.min&.round(5)
  end

  # [width, height] in mm, from the processed image's pixels and DPI — read
  # from the file every time, never stored (a new version changes it; Etapa
  # 2.6a shows a DTF size's measure and orders the sizes by it). nil without
  # size or DPI.
  # Usage: version.medidas_mm # => [16.17, 17.02] (191 × 201 px at 300 dpi)
  def medidas_mm
    meta = image_metadata
    return nil unless meta&.width_px && meta.height_px && meta.dpi.to_f.positive?

    [ meta.width_px, meta.height_px ].map { |px| px * 25.4 / meta.dpi }
  end
end
