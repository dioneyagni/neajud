# Turns a DTF version's file 90° for the RIP (Etapa 2.6b2, D4): queued by
# ArquivoGiradoDtf#preparar! (confirming the pedido, or the Impressão page
# finding it missing). A file the tool can't turn is logged and marked
# (ArquivoGiradoDtf#falhou!); the page then offers the original, for the RIP
# to turn.
#
# Usage: GirarArquivoDtfJob.perform_later(version.id)
class GirarArquivoDtfJob < ApplicationJob
  queue_as :default

  # Injectable: specs use FakeGiroDeArquivo (no tiffcrop on every spec).
  class_attribute :girador, default: GiroDeArquivo.new

  def perform(version_id)
    version = ArquivoVersion.find_by(id: version_id)
    return unless version

    girada = ArquivoGiradoDtf.new(version)
    girador.girar(version.original_path, girada.caminho) unless girada.pronto?
  rescue GiroDeArquivo::Falhou => e
    Rails.logger.error({ job: "GirarArquivoDtfJob", version: version.uuid, error: e.message }.to_json)
    girada.falhou!
  ensure
    girada&.liberar_fila!
  end
end
