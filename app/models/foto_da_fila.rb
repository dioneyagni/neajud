# A photo of the whole queue at the start of one turno (Painel 3/4b,
# decided 07/11/2026, Q1a/Q2a): every stage FilaDeProducao had, where it
# was, when it would end and the hours it had in each turno (VezDaFoto).
# Compared later with the queue of now it tells what was programmed and
# didn't happen — "veio de · adiada N turnos", the load over 100%, the
# virada. Taken by FotoDaFilaJob; one per turno and day (the unique index).
# Deleted after 7 days (derived data, like a reprocessing's): the record
# that stays is ViradaDoPedido.
#
# Usage: FotoDaFila.do_turno(ocorrencia)&.vezes
#        FotoDaFila.terminadas(Time.current).order(:inicio)
class FotoDaFila < ApplicationRecord
  self.table_name = "fotos_da_fila"

  include GeraUuid

  GUARDADAS_POR = 7.days

  belongs_to :turno
  has_many :vezes, class_name: "VezDaFoto", inverse_of: :foto_da_fila, dependent: :delete_all

  validates :data, :inicio, :fim, presence: true

  # The turnos already over at that moment.
  scope :terminadas, ->(agora) { where(fim: ..agora) }

  # Usage: FotoDaFila.do_turno(calendario.agora)
  def self.do_turno(ocorrencia)
    ocorrencia && find_by(turno_id: ocorrencia.turno.id, data: ocorrencia.data)
  end

  # Photos past the 7 days they are kept, with their stages.
  # Usage: FotoDaFila.vencidas(Time.current).destroy_all
  def self.vencidas(agora)
    where(fim: ...(agora - GUARDADAS_POR))
  end

  def turno_nome
    turno.nome
  end
end
