# Compacts a corrida's or cor lisa's file for the RIP (Etapa 2.7c, decided
# 19/10/2026: done when the file is uploaded, so a pedido finds it ready) —
# the thin interface over the tool that does it:
#   TIFF: tiffcp -c lzw:2 (libtiff-tools) keeps every sample — the spot
#     channels included — but drops the Photoshop block holding their names,
#     copied back (BlocoPhotoshopDoTiff), as the DTF's turn does.
# Other formats aren't compacted (compacta? false): the original goes.
# Written to a temporary name and moved, so a half-written file is never
# served; a result not smaller than the original raises (the original goes).
#
# Usage: CompactacaoDeArquivo.new.compactar("…/original/CR-12.tif", "…/tecido/compactado.tif")
class CompactacaoDeArquivo
  FORMATOS = %w[.tif .tiff].freeze

  class Falhou < StandardError; end

  # Usage: CompactacaoDeArquivo.compacta?("CR-12.TIF") # => true
  def self.compacta?(nome)
    FORMATOS.include?(File.extname(nome.to_s).downcase)
  end

  def compactar(origem, destino)
    raise Falhou, "can't compact #{File.basename(origem.to_s).inspect}: expected an existing file ending in #{FORMATOS.join(", ")}" unless self.class.compacta?(origem) && File.exist?(origem)

    FileUtils.mkdir_p(File.dirname(destino))
    temporario = "#{destino}.parcial"
    tiffcp(origem, temporario)
    BlocoPhotoshopDoTiff.copiar(origem, temporario)
    recusar_maior(origem, temporario)
    File.rename(temporario, destino)
  ensure
    FileUtils.rm_f(temporario) if temporario
  end

  private

  def tiffcp(origem, destino)
    return if system("tiffcp", "-c", "lzw:2", origem.to_s, destino, out: File::NULL, err: File::NULL) && File.size?(destino)

    raise Falhou, "tiffcp failed compacting #{File.basename(origem.to_s).inspect}"
  end

  def recusar_maior(origem, compactado)
    return if File.size(compactado) < File.size(origem)

    raise Falhou, "#{File.basename(origem.to_s).inspect} compacted to #{File.size(compactado)} bytes, not smaller than its #{File.size(origem)}"
  end
end
