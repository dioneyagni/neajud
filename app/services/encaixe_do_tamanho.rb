# Meters of fabric one piece of a size takes on a roll of a given width
# (Etapa 2.2, 1/3; decided 07/10/2026): a simple nesting of its DXF
# (bin/encaixe-dxf.js — copies of the piece, 0° or 180°), computed once per
# width and kept in tamanhos.metros_por_peca, cleared when the size's DXF is
# extracted again. Reads the DXF PreparacaoTamanhosJob extracted; without
# it, nothing is computed (nil).
#
# Usage: EncaixeDoTamanho.call(tamanho, 1400) # => 0.01831
class EncaixeDoTamanho
  SCRIPT = Rails.root.join("bin", "encaixe-dxf.js").to_s

  def self.call(tamanho, largura_mm)
    new(tamanho, largura_mm).call
  end

  def initialize(tamanho, largura_mm)
    @tamanho = tamanho
    @largura_mm = largura_mm.to_i
  end

  def call
    guardado = @tamanho.metros_por_peca_em(@largura_mm)
    return guardado if guardado
    return nil unless dxf && File.exist?(dxf)

    calcular.tap { |metros| guardar(metros) if metros }
  end

  private

  def dxf
    version = @tamanho.arquivo.approved_version
    version && @tamanho.dxf_extraido_path(version)
  end

  def calcular
    saida, erro, status = Open3.capture3("node", SCRIPT, dxf, @largura_mm.to_s)
    return JSON.parse(saida)["metros_por_peca"] if status.success?

    Rails.logger.error({ evento: "encaixe_dxf_falhou", tamanho: @tamanho.uuid, largura_mm: @largura_mm, erro: erro.strip }.to_json)
    nil
  end

  def guardar(metros)
    @tamanho.update_column(:metros_por_peca, @tamanho.metros_por_peca.merge(@largura_mm.to_s => metros))
  end
end
