class Tamanho < ApplicationRecord
  include GeraUuid
  belongs_to :arquivo, foreign_key: :arquivo_id
  validates :nome, presence: true
  default_scope { order(:position) }

  # This size's own DXF, extracted from the corte's version (Etapa 0.6): made
  # by PreparacaoTamanhosJob with the preview, downloaded by production.
  # Named by position — never by nome, which is free text (path traversal
  # fixed in #97).
  # Usage: tamanho.dxf_extraido_path(corte.approved_version)
  def dxf_extraido_path(version)
    File.join(version.storage_dir, "tamanho_previews", "#{position}.dxf")
  end
end
