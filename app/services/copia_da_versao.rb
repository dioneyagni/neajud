# A file derived from a version for the RIP and kept beside it, made in the
# background (Etapa 2.7c, decided 19/10/2026 — the second use after the
# DTF's turned copy, ArquivoGiradoDtf): the queue mark (a dead job never
# leaves the page waiting), the failure mark (never tried again; the
# original goes) and the ready check. The includer gives `caminho` (rebuilt
# from the version, never from a typed name), `aplica?` (the format is one
# the tool handles) and `job` (queued with the version's id).
#
# Usage: copia.preparar! # queues the job unless it doesn't apply, is ready, queued or failed
#        copia.pronto?   # => true once the job wrote it
module CopiaDaVersao
  # The same expiry as the other queued tasks.
  EXPIRA = Arquivo::TAREFA_EM_FILA_EXPIRA

  def initialize(version)
    @version = version
  end

  def pronto?
    File.exist?(caminho)
  end

  def em_fila?
    File.exist?(marca) && File.mtime(marca) > EXPIRA.ago
  end

  def falhou?
    File.exist?(falha)
  end

  def preparar!
    return if !aplica? || falhou? || pronto? || em_fila?

    FileUtils.mkdir_p(File.dirname(marca))
    FileUtils.touch(marca)
    job.perform_later(@version.id)
  end

  # Called by the job when it ends, done or not.
  def liberar_fila!
    FileUtils.rm_f(marca)
  end

  # The tool failed (or gave nothing better) on this version's file.
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
