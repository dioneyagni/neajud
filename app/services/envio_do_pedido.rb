# A client's draft between him and the factory (Etapa 2.8, 5/5, decided
# 12/10/2026): he sends it ("Enviar para a fábrica" — pendências never stop
# it), takes it back while it isn't confirmed ("Retirar o envio"), and the
# team returns it with a note. Each step moves the status and writes an
# EventoPedido; a refused one comes back unsaved with its errors.
#
# Usage: evento = EnvioDoPedido.enviar(pedido, user: Current.user)
#        evento.persisted? # => false with evento.errors when refused
#        EnvioDoPedido.devolver(pedido, user: Current.user, recado: "Falta a língua 35")
module EnvioDoPedido
  # Usage: EnvioDoPedido.enviar(pedido, user: Current.user)
  def self.enviar(pedido, user:)
    evento = pedido.eventos_pedido.new(user: user, tipo: "enviado")
    evento.errors.add(:base, "#{pedido.rotulo_lixeira} has no items; add an arte before sending it") if pedido.itens_pedido.none?
    mover(pedido, evento, de: "rascunho", para: "enviado")
  end

  # Usage: EnvioDoPedido.retirar(pedido, user: Current.user)
  def self.retirar(pedido, user:)
    mover(pedido, pedido.eventos_pedido.new(user: user, tipo: "retirado"), de: "enviado", para: "rascunho")
  end

  # Usage: EnvioDoPedido.devolver(pedido, user: Current.user, recado: "Falta a língua 35")
  def self.devolver(pedido, user:, recado:)
    evento = pedido.eventos_pedido.new(user: user, tipo: "devolvido", recado: recado.to_s.strip.presence)
    mover(pedido, evento, de: "enviado", para: "rascunho")
  end

  # Saves the event and the new status together, only from the expected one
  # and never on a frozen pedido (trash, old grade, reposição).
  def self.mover(pedido, evento, de:, para:)
    evento.errors.add(:base, "#{pedido.rotulo_lixeira} is #{pedido.status}; expected #{de} to be #{evento.tipo}") unless pedido.status == de
    evento.errors.add(:base, "#{pedido.rotulo_lixeira} is frozen (trash, old grade or reposição)") unless pedido.confirmavel?
    return evento if evento.errors.any? || evento.invalid?

    Pedido.transaction do
      evento.save!
      pedido.update!(status: para)
    end
    evento
  end
  private_class_method :mover
end
