# What a virada did to a pedido (Painel 3/4b, decided 07/11/2026, Q5a/Q6a):
# a turno started with stages programmed for the one before still open,
# and this pedido's previsão moved to a later day. The turno's name and the
# stages that didn't end are copied (the photo goes after 7 days); never
# deleted — the history of the programação, the team's only. The current
# turno's ones that came to be late are the warning at the Painel's top.
#
# Usage: ViradaDoPedido.do_turno_de(Time.current).atrasaram
class ViradaDoPedido < ApplicationRecord
  self.table_name = "viradas_do_pedido"

  include GeraUuid

  belongs_to :pedido

  validates :turno_nome, :data, :turno_fim, :de, presence: true

  # The ones of the turno under way (the photo of the turno it turned to).
  scope :do_turno_de, ->(agora) { where("viradas_do_pedido.turno_fim > ?", agora) }
  scope :atrasaram, -> { where(passou_a_atrasar: true) }
  # Painel 3/4b2: the viradas that waited for a stage of these pedidos (by
  # the uuid's first 8 characters: the first records kept only those).
  # Usage: ViradaDoPedido.esperaram_por([ pedido ])
  scope :esperaram_por, ->(pedidos) {
    prefixos = pedidos.map { |pedido| pedido.uuid.first(8) }
    where("EXISTS (SELECT 1 FROM json_each(viradas_do_pedido.nao_terminaram) WHERE substr(json_extract(json_each.value, '$.pedido'), 1, 8) IN (?))", prefixos)
  }

  # The stages that didn't end, of that pedido.
  # Usage: virada.nao_terminaram_de(pedido).map { |e| e["etapa"] } # => ["Impressão"]
  def nao_terminaram_de(pedido)
    nao_terminaram.select { |e| e["pedido"].first(8) == pedido.uuid.first(8) }
  end
end
