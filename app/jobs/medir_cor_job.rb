# Measures a cor lisa's version (Etapa 2.5b, decided 12/10/2026): its average
# color in CIE Lab, stored on the version — a new version is a tone
# adjustment, measured again. At the first measure the arte gets its family
# and number ("Laranja 1", never changed). Queued when a cor lisa's version
# finishes processing, and when an arte becomes a cor lisa. Then the card and
# the page show it (the same live streams as processing).
#
# Usage: MedirCorJob.perform_later(version.id)
class MedirCorJob < ApplicationJob
  queue_as :default

  # Injectable: specs use FakeMedidaDeCor (no ImageMagick on a fixture).
  class_attribute :medidor, default: MedidaDeCor.new

  def perform(version_id)
    version = ArquivoVersion.find(version_id)
    arquivo = version.arquivo
    arte = arquivo.arte
    return unless arte&.tipo == "cor_lisa" && version.status == "processed"

    medida = medir(version)
    return unless medida
    l, a, b = medida[:lab]
    version.update!(lab_l: l, lab_a: a, lab_b: b, cor_hex: medida[:hex])
    arte.batizar!(medida[:lab]) if arquivo.approved_version_id == version.id
    arquivo.reload.redesenhar_cartao!([])
    CanaisAoVivo.recarregar(arquivo)
  end

  private

  # A file ImageMagick can't average (a broken EPS) leaves the color
  # unmeasured — the page says "measuring" — and is logged, never retried.
  def medir(version)
    medidor.medir(version.original_path)
  rescue MedidaDeCor::Falhou => e
    Rails.logger.error({ job: "MedirCorJob", version: version.uuid, error: e.message }.to_json)
    nil
  end
end
