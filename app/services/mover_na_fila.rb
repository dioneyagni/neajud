# Confirms a move in the queue (Painel 3/4a, decided 07/11/2026): saves its
# MovimentoDaFila — the pedidos it pushed on the first one —, and tells each
# pushed pedido whose previsão moved to a later day, in its history, only
# "qui 12/11 → sex 13/11" (Q4: a cliente final learns no reason and no other
# pedido). The reason is required when someone comes to be late (Q5a).
#
# Usage: MoverNaFila.call(ImpactoDoMovimento.call(fila, pedido: p, etapa: "corte", posicao: 1), user: Current.user, motivo: "urgente")
class MoverNaFila
  # Someone comes to be late and no reason was given.
  class SemMotivo < StandardError; end

  def self.call(impacto, user:, motivo:)
    new(impacto, user, motivo.to_s.strip.presence).call
  end

  def initialize(impacto, user, motivo)
    @impacto, @user, @motivo = impacto, user, motivo
  end

  def call
    raise SemMotivo, "#{atrasam} would come to be late: say why" if @impacto.exige_motivo? && @motivo.nil?

    MovimentoDaFila.transaction do
      @impacto.movimentos.each_with_index do |movimento, i|
        movimento.update!(user: @user, motivo: @motivo, empurrados: i.zero? ? registro_dos_empurrados : [])
      end
      avisar_os_empurrados
    end
    @impacto.movimentos
  end

  private

  def atrasam
    @impacto.empurrados.select(&:passa_a_atrasar).map { |e| "##{e.pedido.uuid.first(8)}" }.join(", ")
  end

  def registro_dos_empurrados
    @impacto.empurrados.map { |e| { "pedido_id" => e.pedido.id, "de" => e.de.iso8601, "para" => e.para&.iso8601 } }
  end

  def avisar_os_empurrados
    @impacto.empurrados.each { |empurrado| AvisoDePrevisao.call(empurrado.pedido, de: empurrado.de, para: empurrado.para, user: @user) }
  end
end
