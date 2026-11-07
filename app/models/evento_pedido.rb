# One step of a pedido between the client and the factory (Etapa 2.8, 5/5,
# decided 12/10/2026): the client sent it ("enviado"), took it back
# ("retirado"), or the team returned it with a note ("devolvido"). The
# pedido's history on its page; the latest "devolvido" of a draft is what
# the client reads at the top of his Pedidos. Painel 3/4a (decided
# 07/11/2026): "previsao_mudou" — a move in the queue made its previsão
# worse; the recado is "qui 12/11 → sex 13/11", the only thing a cliente
# final learns of the programação (no reason, no other pedido). Painel
# 3/4b: a virada writes it too, with no person behind it (user nil).
#
# Usage: pedido.eventos_pedido.create!(user: Current.user, tipo: "devolvido", recado: "Falta a língua 35")
class EventoPedido < ApplicationRecord
  self.table_name = "eventos_pedido"

  include GeraUuid

  TIPOS = %w[enviado retirado devolvido previsao_mudou].freeze
  # The ones between the client and the factory, by which a draft is read.
  DO_ENVIO = %w[enviado retirado devolvido].freeze

  belongs_to :pedido
  belongs_to :user, optional: true

  validates :user, presence: { message: "can't be blank: only a previsao_mudou comes from no one (a virada)" }, unless: -> { tipo == "previsao_mudou" }

  validates :tipo, inclusion: { in: TIPOS, message: "%{value} is not a pedido event; expected one of #{TIPOS.join(", ")}" }
  validates :recado, presence: { message: "can't be blank: say what the client must change" }, if: -> { tipo == "devolvido" }
end
