# Etapa 0.6 (1/3): finds the arte's tamanho after its molde is chosen
# (TamanhoAutoAssignService — outline matching with ImageMagick, measured up
# to 37 s), outside the request. Always clears the "searching" mark and
# refreshes the open arte page, found or not, so it never stays "Procurando".
#
# Usage: TamanhoAutoAssignJob.perform_later(arte.id)
class TamanhoAutoAssignJob < ApplicationJob
  queue_as :default

  # Injected so specs use FakeMoldMatcher instead of shelling out to ImageMagick.
  class_attribute :matcher, default: MoldMatchService

  def perform(arquivo_id)
    arte = Arquivo.find_by(id: arquivo_id)
    return unless arte

    begin
      TamanhoAutoAssignService.call(arte, matcher: matcher)
    ensure
      arte.update_column(:buscando_tamanho_desde, nil)
      CanaisAoVivo.recarregar(arte)
    end
  end
end
