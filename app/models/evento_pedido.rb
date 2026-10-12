# One step of a pedido between the client and the factory (Etapa 2.8, 5/5,
# decided 12/10/2026): the client sent it ("enviado"), took it back
# ("retirado"), or the team returned it with a note ("devolvido"). The
# pedido's history on its page; the latest "devolvido" of a draft is what
# the client reads at the top of his Pedidos.
#
# Usage: pedido.eventos_pedido.create!(user: Current.user, tipo: "devolvido", recado: "Falta a língua 35")
class EventoPedido < ApplicationRecord
  self.table_name = "eventos_pedido"

  include GeraUuid

  TIPOS = %w[enviado retirado devolvido].freeze

  belongs_to :pedido
  belongs_to :user

  validates :tipo, inclusion: { in: TIPOS, message: "%{value} is not a pedido event; expected one of #{TIPOS.join(", ")}" }
  validates :recado, presence: { message: "can't be blank: say what the client must change" }, if: -> { tipo == "devolvido" }
end
