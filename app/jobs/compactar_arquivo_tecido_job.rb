# Compacts a corrida's or cor lisa's version for the RIP (Etapa 2.7c,
# decided 19/10/2026): queued by ArquivoCompactadoTecido#preparar! (the
# version processed, the arte becoming a tecido kind, or the production page
# finding it missing). A failure — or a result not smaller — is logged and
# marked (ArquivoCompactadoTecido#falhou!); the original goes then.
#
# Usage: CompactarArquivoTecidoJob.perform_later(version.id)
class CompactarArquivoTecidoJob < ApplicationJob
  queue_as :default

  # Injectable: specs use FakeCompactacaoDeArquivo (no tiffcp on every spec).
  class_attribute :compactador, default: CompactacaoDeArquivo.new

  def perform(version_id)
    version = ArquivoVersion.find_by(id: version_id)
    return unless version

    copia = ArquivoCompactadoTecido.new(version)
    compactador.compactar(version.original_path, copia.caminho) unless copia.pronto?
  rescue CompactacaoDeArquivo::Falhou => e
    Rails.logger.error({ job: "CompactarArquivoTecidoJob", version: version.uuid, error: e.message }.to_json)
    copia.falhou!
  ensure
    copia&.liberar_fila!
  end
end
