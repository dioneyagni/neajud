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

  validates :version_number, presence: true, uniqueness: { scope: :arquivo_id }
  validates :filename, presence: true
  validates :extension, presence: true
  validates :mime_type, presence: true
  validates :original_file, presence: true
  validates :status, presence: true

  scope :approved_first, -> { order(approved: :desc, version_number: :desc) }

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

  private
end
