# The turnos' dates and the Painel's "now" (Painel 2/4a).
module TurnosHelper
  # Usage: dia_com_semana(Date.new(2026, 11, 20)) # => "sex 20/11"
  def dia_com_semana(data)
    "#{Turno::DIAS[data.wday]} #{data.strftime("%d/%m")}"
  end

  # The Painel's header: today, the time and the turno on — or the next one;
  # nil when no turno is registered (or a cliente final, who sees none).
  # Usage: agora_no_painel(calendario) # => "qua 04/11 · 10:40 · turno Manhã (06:00–14:00)"
  def agora_no_painel(calendario, momento = Time.current)
    turno = calendario.agora(momento)
    proxima = turno ? nil : calendario.proxima(momento)
    return if turno.nil? && proxima.nil?

    agora = turno ? "turno #{turno.rotulo}" : "fora de turno · próximo: #{proxima.turno.nome} #{dia_relativo(proxima.data, momento.to_date)} às #{proxima.turno.inicio}"
    "#{dia_com_semana(momento.to_date)} · #{momento.strftime("%H:%M")} · #{agora}"
  end

  private

  def dia_relativo(data, hoje)
    return "hoje" if data == hoje
    return "amanhã" if data == hoje + 1

    dia_com_semana(data)
  end
end
