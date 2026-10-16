# Stands in for GiroDeArquivo (tiffcrop) in specs of the DTF's production:
# "turns" by copying the file, or fails when told. Records what it turned.
#
# Usage: GirarArquivoDtfJob.girador = FakeGiroDeArquivo.new
#        GirarArquivoDtfJob.girador = FakeGiroDeArquivo.new(falha: true)
class FakeGiroDeArquivo
  attr_reader :girados

  def initialize(falha: false)
    @falha = falha
    @girados = []
  end

  def girar(origem, destino)
    @girados << origem.to_s
    raise GiroDeArquivo::Falhou, "fake failure turning #{File.basename(origem)}" if @falha

    FileUtils.mkdir_p(File.dirname(destino))
    FileUtils.cp(origem, destino)
  end
end
