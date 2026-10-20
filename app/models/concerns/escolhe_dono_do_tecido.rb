# Whose fabric a record says (Etapa 2.3d1, decided 19/10/2026): "cliente" or
# "empresa", blank = inherit the level above (DonoDoTecido). Included by the
# levels — Client, Molde, Pedido — and the item, which confirming writes.
#
# Usage: molde.update!(dono_tecido: "empresa"); molde.update!(dono_tecido: "") # inherits again
module EscolheDonoDoTecido
  extend ActiveSupport::Concern

  included do
    normalizes :dono_tecido, with: ->(dono) { dono.presence }
    validates :dono_tecido, inclusion: { in: DonoDoTecido::DONOS, message: "%{value} is not whose fabric; expected one of #{DonoDoTecido::DONOS.join(", ")} or blank (inherits)" }, allow_nil: true
  end
end
