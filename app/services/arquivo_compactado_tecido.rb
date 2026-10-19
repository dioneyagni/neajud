# A corrida's or cor lisa's file compacted for the RIP (Etapa 2.7c, decided
# 19/10/2026): a derived copy of a version, kept beside it at
# <version>/tecido/compactado.<ext>, made by CompactarArquivoTecidoJob when
# the version finishes processing or the arte becomes a corrida or a cor
# lisa — so a pedido finds it ready; the production page queues a missing
# one ("preparando…"). A format the tool doesn't compact, a failure or a
# result not smaller sends the original.
#
# Usage: copia = ArquivoCompactadoTecido.new(version)
#        copia.preparar!
#        copia.para_o_rip # => the compacted path, else the original; nil while preparing
class ArquivoCompactadoTecido
  include CopiaDaVersao

  TIPOS = %w[corrida cor_lisa].freeze

  # Queues the copy of every file of a tecido arte (its kind just changed).
  # Usage: ArquivoCompactadoTecido.preparar_da_arte!(arte)
  def self.preparar_da_arte!(arte)
    arte.arquivos.ativos.includes(:approved_version).filter_map(&:approved_version).select { |v| v.status == "processed" }.each { |v| new(v).preparar! }
  end

  def caminho
    File.join(@version.storage_dir, "tecido", "compactado#{File.extname(@version.original_file).downcase}")
  end

  def compacta?
    aplica? && !falhou?
  end

  def estado
    compacta? && !pronto? ? :preparando : :pronto
  end

  # The file to send; nil while preparing (or the original is gone).
  def para_o_rip
    return nil if estado == :preparando

    caminho = pronto? ? self.caminho : @version.original_path
    caminho if File.exist?(caminho)
  end

  private

  def aplica?
    CompactacaoDeArquivo.compacta?(@version.original_file)
  end

  def job
    CompactarArquivoTecidoJob
  end
end
