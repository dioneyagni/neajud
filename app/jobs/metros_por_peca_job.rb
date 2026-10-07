# Computes, outside the request, the meters per piece of sizes on fabric
# widths (Etapa 2.2, 1/3): after a corte's sizes are prepared (all known
# material widths) and when a material of a new width is registered (every
# size). refazer: the DXF was extracted again, so the old values go first.
#
# Usage: MetrosPorPecaJob.perform_later(corte.tamanhos.ids, [1400, 1600], refazer: true)
class MetrosPorPecaJob < ApplicationJob
  queue_as :default

  # Injected so specs use FakeEncaixe instead of running Node.
  class_attribute :encaixe, default: EncaixeDoTamanho

  def perform(tamanho_ids, larguras_mm, refazer: false)
    Tamanho.where(id: tamanho_ids).find_each do |tamanho|
      tamanho.update_column(:metros_por_peca, {}) if refazer
      larguras_mm.each { |largura| encaixe.call(tamanho, largura) }
    end
  end
end
