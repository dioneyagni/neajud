# The DTF file turned 90° for the RIP (Etapa 2.6b2, D4, decided 15/10/2026):
# a derived copy of a version, kept beside it at <version>/dtf/girada.<ext>
# — the path rebuilt from the version, never from a typed name. Made by
# GirarArquivoDtfJob when a pedido is confirmed, or when the Impressão page
# finds it missing (a new version); "preparando" while queued. The queue and
# failure marks are CopiaDaVersao's (shared with the tecido's compacted copy).
#
# Usage: ArquivoGiradoDtf.new(version).pronto? # => true
#        ArquivoGiradoDtf.new(version).preparar! # queues the job unless ready or queued
class ArquivoGiradoDtf
  include CopiaDaVersao

  # false: a format the RIP turns itself (GiroDeArquivo.gira?), or a file
  # the tool failed on — then the original goes, for the RIP to turn.
  def gira?
    aplica? && !falhou?
  end

  def caminho
    File.join(@version.storage_dir, "dtf", "girada#{File.extname(@version.original_file).downcase}")
  end

  private

  def aplica?
    GiroDeArquivo.gira?(@version.original_file)
  end

  def job
    GirarArquivoDtfJob
  end
end
