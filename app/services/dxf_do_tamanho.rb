require "open3"

# One size's DXF, ready to download (Etapa 0.6, 3/3): normally the file
# PreparacaoTamanhosJob already extracted; if asked before it is ready (or
# the version changed), extracted now into the same place. Shared by the
# single download and the Corte page's zip (Etapa 1.2, 3/3 parte 3b).
#
# Usage: DxfDoTamanho.caminho!(tamanho) # => ".../v1/tamanho_previews/2.dxf"
class DxfDoTamanho
  def self.caminho!(tamanho)
    new(tamanho).caminho!
  end

  def initialize(tamanho)
    @tamanho = tamanho
    @version = tamanho.arquivo.approved_version
  end

  # Raises ActionController::MissingFile when the corte has no original file.
  def caminho!
    raise ActionController::MissingFile, "Corte #{@tamanho.arquivo.uuid} has no original file" unless @version && File.exist?(@version.original_path.to_s)

    caminho = @tamanho.dxf_extraido_path(@version)
    extrair!(caminho) unless em_dia?(caminho)
    caminho
  end

  private

  def em_dia?(caminho)
    File.exist?(caminho) && File.mtime(caminho) >= File.mtime(@version.original_path)
  end

  def extrair!(caminho)
    FileUtils.mkdir_p(File.dirname(caminho))
    _stdout, stderr, status = Open3.capture3(
      "node", Rails.root.join("bin", "extract-tamanho-dxf.js").to_s,
      @version.original_path.to_s, caminho, @tamanho.position.to_s
    )
    return if status.success?

    Rails.logger.error "extract-tamanho-dxf.js failed (position=#{@tamanho.position}): #{stderr.strip}"
    raise "Failed to extract tamanho #{@tamanho.uuid} (position #{@tamanho.position}) from #{@version.original_path}"
  end
end
