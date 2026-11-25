# How the Turnos page says a stop (Máquinas 3/5a, canvas "Máquinas", 6):
# its period, who made it, what it did to the queue when saved and when it
# came back to work.
module ParadasHelper
  # Usage: periodo_da_parada(parada) # => "ter 24/11 – qui 26/11"; one day: "seg 30/11"
  def periodo_da_parada(parada)
    fim = parada.data_fim || parada.data
    fim == parada.data ? dia_com_semana(parada.data) : "#{dia_com_semana(parada.data)} – #{dia_com_semana(fim)}"
  end

  # Usage: autoria_da_parada(parada) # => "Dione · 24/11 09:40"; nil before 3/5a
  def autoria_da_parada(parada)
    "#{parada.user.nome} · #{l(parada.created_at, format: "%d/%m %H:%M")}" if parada.user
  end

  # Usage: impacto_da_parada(parada) # => "atrasou 3 pedidos", "ninguém atrasou"; "—" when none was kept (before 3/5a)
  def impacto_da_parada(parada)
    return "—" unless parada.impacto

    atrasam = parada.impacto["atrasam"].to_i
    atrasam.zero? ? "ninguém atrasou" : "atrasou #{pluralize(atrasam, "pedido", plural: "pedidos")}"
  end

  # Usage: voltou_da_parada(parada) # => "voltou sex 20/11 15:10 · Dione"
  def voltou_da_parada(parada)
    "voltou #{dia_com_semana(parada.voltou_em.to_date)} #{parada.voltou_em.strftime("%H:%M")}#{" · #{parada.voltou_por.nome}" if parada.voltou_por}"
  end

  # One pedido of the impact kept (ImpactoDaParada#registro); pedidos: the visible ones by uuid.
  # Usage: linha_do_impacto(item, pedidos) # => "#5d2f9a10 Impacto · prazo ter 24/11 · previsão ter 24/11 11:40 → sex 27/11 07:36 (presa na Calandra 2)"
  def linha_do_impacto(item, pedidos)
    pedido = pedidos[item["pedido_uuid"]]
    partes = [ "##{item["pedido_uuid"].first(8)}#{" #{pedido.client.name}" if pedido&.client}" ]
    partes << "prazo #{dia_com_semana(Date.iso8601(item["prazo"]))}" if item["prazo"]
    partes << "previsão #{momento_do_impacto(item["de"])} → #{item["para"] ? momento_do_impacto(item["para"]) : "sem previsão"}"
    "#{partes.join(" · ")}#{" (#{item["motivo"]})" if item["motivo"]}"
  end

  # The pedidos that came to be late, the ones it pushed only after them.
  def atrasados_do_impacto(parada)
    Array(parada.impacto&.dig("pedidos")).select { |item| item["passa_a_atrasar"] }
  end

  private

  def momento_do_impacto(iso)
    momento = Time.zone.parse(iso)
    "#{dia_com_semana(momento.to_date)} #{momento.strftime("%H:%M")}"
  end
end
