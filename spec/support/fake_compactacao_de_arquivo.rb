# Stands in for CompactacaoDeArquivo (tiffcp) in specs of the tecido's
# production: "compacts" by copying the file, or fails when told. Records
# what it compacted.
#
# Usage: CompactarArquivoTecidoJob.compactador = FakeCompactacaoDeArquivo.new
#        CompactarArquivoTecidoJob.compactador = FakeCompactacaoDeArquivo.new(falha: true)
class FakeCompactacaoDeArquivo
  attr_reader :compactados

  def initialize(falha: false)
    @falha = falha
    @compactados = []
  end

  def compactar(origem, destino)
    @compactados << origem.to_s
    raise CompactacaoDeArquivo::Falhou, "fake failure compacting #{File.basename(origem)}" if @falha

    FileUtils.mkdir_p(File.dirname(destino))
    FileUtils.cp(origem, destino)
  end
end
