# What the RIP gets for one DTF line (Etapa 2.6b2, D4, decided 15/10/2026):
# the size's file — turned 90° when the fit turned it — named with the
# units to print, "DTF-4_ENCRUZILHADA DO SUL_P_128un_girada.tif". The RIP
# lays out the sheet. A file the system can't turn (PSD, PDF, or the tool
# failed) goes as it is, "_girar-no-RIP".
#
# Usage: rip = ArquivoDtfParaRip.new(linha) # a LinhasDeProducao::Linha of the DTF
#        rip.estado # => :pronto / :preparando
#        rip.nome   # => "DTF-4_ENCRUZILHADA DO SUL_P_128un_girada.tif"
class ArquivoDtfParaRip
  def initialize(linha)
    @linha = linha
    @version = linha.arquivo.approved_version
  end

  def girada?
    @linha.encaixe.girada == true
  end

  def estado
    girada? && girado.gira? && !girado.pronto? ? :preparando : :pronto
  end

  # The file to send; nil while preparing (or the original is gone).
  def caminho
    return nil if estado == :preparando

    caminho = girada? && girado.gira? ? girado.caminho : @version.original_path
    caminho if File.exist?(caminho)
  end

  def nome
    base = @linha.arquivo.nome_completo(para_arquivo: true) || File.basename(@version.original_file, ".*")
    "#{base}_#{@linha.encaixe.impressas}un#{sufixo_do_giro}#{File.extname(@version.original_file).downcase}"
  end

  # Queues the turned copy when it is missing.
  def preparar!
    girado.preparar! if girada?
  end

  private

  def girado
    @girado ||= ArquivoGiradoDtf.new(@version)
  end

  def sufixo_do_giro
    return "" unless girada?

    girado.gira? ? "_girada" : "_girar-no-RIP"
  end
end
