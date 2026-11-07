# A stage moved in its sector's queue (Painel 3/4a, decided 07/11/2026,
# Q1a–Q7c): who moved it, from which place to which, why, and the pedidos
# whose previsão it made worse (empurrados). The programação keeps only
# these; the queue goes on being computed (FilaDeProducao), each stage's
# last movement while it is open giving its order: ordem_em — it sorts as
# if it had arrived then — or nil, back to its arrival. Never deleted: the
# history of the programação, seen by the team only.
#
# Usage: MovimentoDaFila.create!(pedido: p, user: u, etapa: "impressao", setor: "impressao", de: 3, para: 1,
#                                ordem_em: outro.confirmado_em - 0.001, motivo: "cliente pediu urgência")
#        MovimentoDaFila.ordens # => { [pedido_id, "impressao"] => 2026-11-04 09:59:59.999 }
class MovimentoDaFila < ApplicationRecord
  self.table_name = "movimentos_da_fila"

  include GeraUuid
  include AvisaAFila

  belongs_to :pedido
  belongs_to :user

  validates :etapa, :setor, presence: true

  # The order in force of each moved stage: its last movement's (nil ones,
  # back to the arrival, are left out).
  def self.ordens
    ultimos = group(:pedido_id, :etapa).maximum(:id).values
    where(id: ultimos).where.not(ordem_em: nil).to_h { |movimento| [ [ movimento.pedido_id, movimento.etapa ], movimento ] }
  end

  # The movements that touched the pedido: its own, and the ones that pushed it.
  # Usage: MovimentoDaFila.do_pedido(pedido).map(&:motivo)
  def self.do_pedido(pedido)
    dos_pedidos([ pedido.id ])
  end

  # The same for many pedidos in one query (the Painel's rows).
  # Usage: MovimentoDaFila.por_pedido([ 1, 2 ]) # => { 1 => [movimento], 2 => [] }
  def self.por_pedido(ids)
    movimentos = dos_pedidos(ids).to_a
    ids.index_with { |id| movimentos.select { |m| m.pedido_id == id || m.empurrado_id?(id) } }
  end

  def self.dos_pedidos(ids)
    empurrou = where("EXISTS (SELECT 1 FROM json_each(movimentos_da_fila.empurrados) WHERE json_extract(json_each.value, '$.pedido_id') IN (?))", ids)
    where(pedido_id: ids).or(empurrou).includes(:user, :pedido).order(:id)
  end

  def empurrado_id?(id)
    empurrados.any? { |e| e["pedido_id"] == id }
  end

  # Back to the arrival order (one stage, or the whole sector).
  def voltou?
    ordem_em.nil?
  end

  # What it did to that pedido: { "de" => …, "para" => … } (times, ISO 8601), or nil.
  def empurrado(pedido)
    empurrados.find { |e| e["pedido_id"] == pedido.id }
  end
end
