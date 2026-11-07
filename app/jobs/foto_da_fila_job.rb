# Every 5 minutes (config/recurring.yml, Painel 3/4b Q2a): the photo of the
# turno under way, if it has none yet, and its virada (TirarFotoDaFila).
# In development it is scheduled only with FOTOS_DA_FILA=1: it writes to
# the real data there.
class FotoDaFilaJob < ApplicationJob
  queue_as :default

  def perform
    TirarFotoDaFila.call
  rescue StandardError => e
    Rails.logger.error("FotoDaFilaJob failed for the turno under way at #{Time.current.iso8601}: #{e.class}: #{e.message}")
    raise
  end
end
