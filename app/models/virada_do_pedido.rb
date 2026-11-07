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
end
