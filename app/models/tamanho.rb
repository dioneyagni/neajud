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

  # Does this size serve the size read from a file name (Etapa 1.2, 2/3)?
  # Numbers must all be among the ones it serves ("30" or "29-30" → 29-30);
  # a label must be its name ("p" → P).
  # Usage: tamanho.atende_rotulo?("30") # => true for 29-30
  def atende_rotulo?(rotulo)
    numeros_do_rotulo = GradeDoCorte.numeros_do_texto(rotulo)
    return nome.casecmp?(rotulo.to_s.strip) if numeros_do_rotulo.empty?

    nome == rotulo || (numeros.present? && (numeros_do_rotulo - numeros).empty?)
  end
end
