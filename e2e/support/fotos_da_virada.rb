# The E2E's virada (Painel 3/4b): the photos of the last turno already over
# and of the one under way (or the next), taken by the app's own
# TirarFotoDaFila as if the job had run then — a spec can't wait for a turno
# to end. Prints, as JSON, the turno it turned from and whether the pedido
# asked had its stages programmed to end in it.
#
# Usage: bin/rails runner -e test e2e/support/fotos_da_virada.rb <pedido uuid>
pedido = Pedido.por_uuid!(ARGV.fetch(0))
agora = Time.current
calendario = CalendarioDeProducao.new
anterior = calendario.ocorrencias(de: agora - 8.days, ate: agora).select { |ocorrencia| ocorrencia.fim <= agora }.last
abort "No turno ended in the last 8 days: the spec registers one every day" unless anterior

foto = TirarFotoDaFila.call(agora: anterior.inicio, calendario: calendario) || abort("The turno #{anterior.rotulo} already had its photo")
# Between turnos, the next one's photo, taken as it starts.
TirarFotoDaFila.call(agora: calendario.agora(agora) ? agora : calendario.proxima(agora).inicio, calendario: calendario)
terminam = foto.vezes.where(pedido: pedido).all?(&:terminaria_no_turno?)
puts({ anterior: anterior.turno.nome, data: anterior.data.iso8601, terminam: terminam, viradas: ViradaDoPedido.where(pedido: pedido).count }.to_json)
