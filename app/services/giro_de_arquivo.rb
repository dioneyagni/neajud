# Turns a DTF file 90° for the RIP (Etapa 2.6b2, D4/D4.1, decided
# 15/10/2026) — the thin interface over the tools that do it:
#   TIFF: tiffcrop -R 90 (libtiff-tools) rotates every sample untouched —
#     ImageMagick 6 dropped one of two spot channels (the white) — then the
#     Photoshop block with the spots' names is copied back
#     (BlocoPhotoshopDoTiff);
#   PNG: ImageMagick (no spot channels there).
# Other formats aren't turned (gira? false): the RIP turns them.
# Written to a temporary name and moved, so a half-written file is never
# served.
#
# Usage: GiroDeArquivo.new.girar("…/original/P.tif", "…/dtf/girada.tif")
class GiroDeArquivo
  FORMATOS = { ".tif" => :tiff, ".tiff" => :tiff, ".png" => :png }.freeze

  class Falhou < StandardError; end

  # Usage: GiroDeArquivo.gira?("P.TIF") # => true
  def self.gira?(nome)
    FORMATOS.key?(File.extname(nome.to_s).downcase)
  end

  def girar(origem, destino)
    formato = FORMATOS.fetch(File.extname(origem).downcase) { raise Falhou, "can't turn #{File.basename(origem).inspect}: expected one of #{FORMATOS.keys.join(", ")}" }
    FileUtils.mkdir_p(File.dirname(destino))
    temporario = "#{destino}.parcial"
    formato == :tiff ? girar_tiff(origem, temporario) : girar_png(origem, temporario)
    File.rename(temporario, destino)
  ensure
    FileUtils.rm_f(temporario) if temporario
  end

  private

  def girar_tiff(origem, destino)
    executar(origem, "tiffcrop", "-R", "90", origem, destino)
    BlocoPhotoshopDoTiff.copiar(origem, destino)
  end

  def girar_png(origem, destino)
    executar(origem, "convert", "#{origem}[0]", "-rotate", "90", destino)
  end

  def executar(origem, *comando)
    return if system(*comando, out: File::NULL, err: File::NULL) && File.size?(comando.last)

    raise Falhou, "#{comando.first} failed turning #{File.basename(origem).inspect}"
  end
end
