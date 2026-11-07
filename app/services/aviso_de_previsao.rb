# Tells a pedido, in its history, that its previsão moved to a later day
# (Painel 3/4a Q4, 3/4b Q6a): only "qui 12/11 → sex 13/11" — what a cliente
# final reads, no reason and no other pedido. Within the same day, nothing.
# A move (MoverNaFila) and a virada (ViradaDaFila, user nil) both tell it.
#
# Usage: AvisoDePrevisao.call(pedido, de: previsao_antes, para: previsao_agora, user: Current.user)
class AvisoDePrevisao
  # para nil: no previsão any more. Returns the event, or nil when the day stayed.
  def self.call(pedido, de:, para:, user: nil)
    return unless mudou_de_dia?(de, para)

    pedido.eventos_pedido.create!(user: user, tipo: "previsao_mudou", recado: "#{dia(de)} → #{para ? dia(para) : "sem previsão"}")
  end

  # Usage: AvisoDePrevisao.mudou_de_dia?(quarta_15h, quinta_09h) # => true
  def self.mudou_de_dia?(de, para)
    para.nil? || para.to_date > de.to_date
  end

  # A reposição's deadline is its original's: the client waits for those pieces.
  def self.prazo(pedido)
    pedido.prazo_entrega || pedido.reposicao_de&.prazo_entrega
  end

  # On time before, late after (or no previsão any more).
  # Usage: AvisoDePrevisao.passa_a_atrasar?(Date.new(2026, 11, 12), quarta, sexta) # => true
  def self.passa_a_atrasar?(prazo, de, para)
    prazo.present? && de.to_date <= prazo && (para.nil? || para.to_date > prazo)
  end

  def self.dia(momento)
    Turno.dia_com_semana(momento.to_date)
  end
end
