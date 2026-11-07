# One stage of one pedido in a FotoDaFila (Painel 3/4b): its place, when the
# queue had it end (nil: no previsão), the pedido's previsão then, and its
# pieces in the turnos. Rows inside a photo, never addressed from outside
# (no uuid, like a pedido item's sizes), deleted with it.
#
# Usage: vez.horas_em(ocorrencia.inicio...ocorrencia.fim) # => 2.5
class VezDaFoto < ApplicationRecord
  self.table_name = "vezes_da_foto"

  belongs_to :foto_da_fila, inverse_of: :vezes
  belongs_to :pedido

  validates :etapa, :setor, presence: true

  # The hours its pieces had inside the period.
  def horas_em(periodo)
    trechos.sum do |trecho|
      inicio, fim = Time.zone.parse(trecho["inicio"]), Time.zone.parse(trecho["fim"])
      [ [ fim, periodo.end ].min - [ inicio, periodo.begin ].max, 0 ].max / 3600.0
    end
  end

  # The queue had it end within its photo's turno.
  def terminaria_no_turno?
    fim.present? && fim <= foto_da_fila.fim
  end
end
