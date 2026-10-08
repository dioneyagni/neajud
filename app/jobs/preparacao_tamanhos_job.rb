# Etapa 0.6 (2/3 + 3/3): prepares a corte's tamanhos outside the request —
# re-detects them when organizing had failed (DxfOrganizationService.call),
# else extracts each size's DXF and draws its preview. The extracted DXF is
# what production downloads (TamanhosController#download), and the preview
# is what the automatic tamanho search compares. Then each size's meters per
# piece on the materials' widths are computed again (Etapa 2.2, 1/3). Always
# clears the mark and
# refreshes the corte page, so it never stays "Preparando".
#
# Usage: PreparacaoTamanhosJob.perform_later(corte.id, true)
class PreparacaoTamanhosJob < ApplicationJob
  queue_as :default

  # Injected so specs use FakeOrganizadorDxf instead of running Node + ImageMagick.
  class_attribute :organizador, default: DxfOrganizationService

  def perform(arquivo_id, redetectar = false)
    corte = Arquivo.find_by(id: arquivo_id)
    return unless corte

    begin
      redetectar ? organizador.call(corte) : organizador.generate_tamanho_previews(corte)
      MetrosPorPecaJob.perform_later(corte.tamanhos.ids, MateriaPrima.larguras_mm, refazer: true)
    ensure
      corte.update_column(:preparando_tamanhos_desde, nil)
      corte.broadcast_refresh
    end
  end
end
