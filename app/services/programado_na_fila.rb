# What the photos (FotoDaFila) programmed, against the queue of now
# (Painel 3/4b, decided 07/11/2026):
#
#   adiamento — a stage the photo of a turno already over had end in that
#     turno, still open (Q3a): the first such turno and how many. A stage
#     only passing through a turno (it would end in a later one) doesn't count;
#   pendentes_do_dia / pendentes_do_turno — the hours today's first photo
#     (or the turno's) programmed for today (the turno) still to do (Q7a):
#     per stage, the hours it had there, at most what it has left now. Over
#     the hours left, the load passes 100% — the turno fell behind.
#
# fotos: the photos this person sees (none for a cliente final); only the
# last 7 days exist (adiada counts at most those).
#
# Usage: programado = ProgramadoNaFila.new(visiveis(FotoDaFila), fila)
#        programado.adiamento(vez)                  # => #<Adiamento veio_de="Manhã", veio_em=…, turnos=2>
#        programado.pendentes_do_dia("impressao")   # => 5.2 (nil: no photo today)
class ProgramadoNaFila
  Adiamento = Struct.new(:veio_de, :veio_em, :turnos, keyword_init: true)

  def initialize(fotos, fila)
    @fotos, @fila = fotos, fila
    @abertas = fila.pedidos.flat_map { |pedido| fila.previsao(pedido).vezes }.index_by { |vez| [ vez.pedido.id, vez.etapa.chave ] }
  end

  # Usage: programado.adiamento(fila.do_setor("corte").first) # => nil when it ran as programmed
  def adiamento(vez)
    adiamentos[[ vez.pedido.id, vez.etapa.chave ]]
  end

  # The hours the day's first photo programmed for today, in the sector, not done yet.
  def pendentes_do_dia(setor)
    foto = fotos_de_hoje.first
    hoje = @fila.agora.to_date
    turnos = @fila.calendario.ocorrencias(de: hoje.in_time_zone, ate: (hoje + 1).in_time_zone).select { |ocorrencia| ocorrencia.data == hoje }
    foto && turnos.any? && pendentes(foto, setor, turnos.first.inicio...turnos.last.fim)
  end

  # The same for the turno, from its own photo (only the one under way has it).
  def pendentes_do_turno(setor, ocorrencia)
    foto = fotos_de_hoje.find { |outra| outra.turno_id == ocorrencia.turno.id && outra.data == ocorrencia.data }
    foto && pendentes(foto, setor, ocorrencia.inicio...ocorrencia.fim)
  end

  private

  def adiamentos
    @adiamentos ||= adiadas.group_by { |linha| [ linha.pedido_id, linha.etapa ] }.transform_values do |linhas|
      primeira = linhas.min_by { |linha| linha.foto_da_fila.inicio }.foto_da_fila
      Adiamento.new(veio_de: primeira.turno_nome, veio_em: primeira.data, turnos: linhas.size)
    end
  end

  # The stages programmed to end in a turno already over, still open now.
  def adiadas
    VezDaFoto.joins(:foto_da_fila).merge(@fotos.terminadas(@fila.agora))
             .where(pedido_id: @fila.pedidos.map(&:id)).where("vezes_da_foto.fim <= fotos_da_fila.fim")
             .includes(foto_da_fila: :turno).select { |linha| @abertas.key?([ linha.pedido_id, linha.etapa ]) }
  end

  def fotos_de_hoje
    @fotos_de_hoje ||= @fotos.where(data: @fila.agora.to_date).includes(:vezes, :turno).order(:inicio).to_a
  end

  def pendentes(foto, setor, periodo)
    foto.vezes.select { |linha| linha.setor == setor }.sum do |linha|
      resta = @abertas[[ linha.pedido_id, linha.etapa ]]&.horas || 0
      [ linha.horas_em(periodo), resta ].min
    end
  end
end
