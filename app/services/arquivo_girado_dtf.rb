# The DTF file turned 90° for the RIP (Etapa 2.6b2, D4, decided 15/10/2026):
# a derived copy of a version, kept beside it at <version>/dtf/girada.<ext>
# — the path rebuilt from the version, never from a typed name. Made by
# GirarArquivoDtfJob when a pedido is confirmed, or when the Impressão page
# finds it missing (a new version); "preparando" while queued.
#
# Usage: ArquivoGiradoDtf.new(version).pronto? # => true
#        ArquivoGiradoDtf.new(version).preparar! # queues the job unless ready or queued
class ArquivoGiradoDtf
  # A queue mark older than this counts as over (a dead job never leaves
  # the page waiting) — the same as the other queued tasks.
  EXPIRA = Arquivo::TAREFA_EM_FILA_EXPIRA

  def initialize(version)
    @version = version
  end

  # false: a format the RIP turns itself (GiroDeArquivo.gira?), or a file
  # the tool failed on — then the original goes, for the RIP to turn.
  def gira?
    GiroDeArquivo.gira?(@version.original_file) && !File.exist?(falha)
  end

  def caminho
    File.join(@version.storage_dir, "dtf", "girada#{File.extname(@version.original_file).downcase}")
  end

  def pronto?
    File.exist?(caminho)
  end

  def em_fila?
    File.exist?(marca) && File.mtime(marca) > EXPIRA.ago
  end

  def preparar!
    return if !gira? || pronto? || em_fila?

    FileUtils.mkdir_p(File.dirname(marca))
    FileUtils.touch(marca)
    GirarArquivoDtfJob.perform_later(@version.id)
  end

  # Called by the job when it ends, done or not.
  def liberar_fila!
    FileUtils.rm_f(marca)
  end

  # The tool failed on this version's file: never tried again.
  def falhou!
    FileUtils.mkdir_p(File.dirname(falha))
    FileUtils.touch(falha)
  end

  private

  def marca
    "#{caminho}.fila"
  end

  def falha
    "#{caminho}.falhou"
  end
end
