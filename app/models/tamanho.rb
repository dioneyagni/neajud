class Tamanho < ApplicationRecord
  include GeraUuid
  belongs_to :arquivo, foreign_key: :arquivo_id
  validates :nome, presence: true
  default_scope { order(:position) }

  # What the cutting machine goes through in one piece (Painel 2/4a2).
  # por_camada: false while the size is not measured by layer yet.
  CorteDaMaquina = Struct.new(:linha_mm, :furos, :por_camada, keyword_init: true)

  # This size's own DXF, extracted from the corte's version (Etapa 0.6): made
  # by PreparacaoTamanhosJob with the preview, downloaded by production.
  # Named by position — never by nome, which is free text (path traversal
  # fixed in #97).
  # Usage: tamanho.dxf_extraido_path(corte.approved_version)
  def dxf_extraido_path(version)
    File.join(version.storage_dir, "tamanho_previews", "#{position}.dxf")
  end

  # The size's drawing, made next to its DXF (DxfOrganizationService); nil
  # without a version.
  # Usage: tamanho.preview_png_path(corte.approved_version)
  def preview_png_path(version)
    version && File.join(version.storage_dir, "tamanho_previews", "#{position}.png")
  end

  # Meters of a roll of this width one piece takes (EncaixeDoTamanho), or
  # nil while not computed.
  # Usage: tamanho.metros_por_peca_em(1400) # => 0.01831
  def metros_por_peca_em(largura_mm)
    metros_por_peca[largura_mm.to_i.to_s]
  end

  # One piece's cut (Painel 2/4a2, decided 06/11/2026): the contour plus the
  # inner lines of the layers marked Cut, and the closed figures of the ones
  # marked Hole (each a 2 s punch, not a line); Engraving and Ignore don't
  # go through the machine. A color with no layer is cut (CutLayer's
  # default). Measured before the layers were (linhas_por_cor nil): the
  # whole line, no holes. nil without any measure.
  # anotacoes: { "#FF0000" => "hole", … }, the corte's CutLayer by color.
  # Usage: tamanho.corte_da_maquina("#00FF00" => "hole").furos # => 10
  def corte_da_maquina(anotacoes)
    return (CorteDaMaquina.new(linha_mm: total_line_mm.to_f, furos: 0, por_camada: false) if total_line_mm) if linhas_por_cor.nil?
    return if perimeter_mm.nil?

    camadas = linhas_por_cor.group_by { |cor, _| anotacoes.fetch(cor.upcase, "cut") }.transform_values { |cores| cores.map(&:last) }
    CorteDaMaquina.new(linha_mm: perimeter_mm.to_f + Array(camadas["cut"]).sum { |cor| cor["mm"].to_f },
                       furos: Array(camadas["hole"]).sum { |cor| cor["figuras"].to_i }, por_camada: true)
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
