# A stage's first plan (Painel 3/4b2, decided 07/11/2026, Q8a): the first
# photo (FotoDaFila) that had it after the pedido's confirmation — when it
# would end and its pieces in the turnos. The faixa draws it dashed against
# the queue of now. Kept apart from the photos (deleted after 7 days) until
# 7 days after the delivery; rows inside a pedido, never addressed from
# outside (no uuid, like VezDaFoto).
#
# Usage: PlanoDaEtapa.where(pedido: p).index_by(&:etapa)["impressao"].fim
#        PlanoDaEtapa.vencidos(Time.current).delete_all
class PlanoDaEtapa < ApplicationRecord
  self.table_name = "planos_da_etapa"

  GUARDADO_POR = 7.days

  belongs_to :pedido

  validates :etapa, :setor, :turno_nome, :data, presence: true

  # The plans of pedidos delivered more than 7 days ago (the Painel shows
  # the delivered ones of the last 7 days).
  def self.vencidos(agora)
    where(pedido: Pedido.where(entregue_em: ...(agora - GUARDADO_POR)))
  end

  # Its pieces as times: [[inicio, fim]].
  def periodos
    trechos.map { |trecho| [ Time.zone.parse(trecho["inicio"]), Time.zone.parse(trecho["fim"]) ] }
  end
end
