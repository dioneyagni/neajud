# Each machine's load per day in the Linha do tempo (Máquinas 5/5, decided
# 25/11/2026, Q1a, canvas "Máquinas", 13): the sector's row sums them as
# before; its ▸ opens a row per machine. The same rules as the sector's
# (LinhaDoTempo): the hours the machine has in the day's turnos — none
# where it stops (3/5) —, today only from now on; what the queue puts on
# it, another sector's pieces included (2/5a, Q1a: one agenda). The photo
# of the turno is the sector's (2/5): a machine's day is never "estourado".
#
# Usage: maquinas = CargaDasMaquinas.new(fila, calendario, agora).do_setor("estamparia", dias, &ocorrencias_do_dia)
#        maquinas.first.celulas.map(&:estado) # => [:passado, :passado, :parada, …]
class CargaDasMaquinas
  # maquina: its Maquina; celulas: LinhaDoTempo::CelulaDaCarga, one per day.
  Linha = Struct.new(:maquina, :celulas, keyword_init: true)

  def initialize(fila, calendario, agora)
    @fila, @calendario, @agora = fila, calendario, agora
  end

  # The sector's machines, in lane order; none for a sector without them.
  # ocorrencias: given a date, the turnos the factory works that day.
  def do_setor(setor, datas, &ocorrencias)
    @fila.recursos_do_setor(setor).select { |recurso, _| recurso.maquina? }.map do |recurso, etapas|
      Linha.new(maquina: recurso.maquina, celulas: datas.map { |data| celula(recurso, etapas, data, ocorrencias.call(data)) })
    end
  end

  private

  def celula(recurso, etapas, data, turnos)
    return nova(data, :passado) if data < @agora.to_date
    return nova(data, :sem_turno) if turnos.empty?
    return nova(data, :parada) if turnos.all? { |ocorrencia| etapas.all? { |etapa| @calendario.parada?(ocorrencia, etapa, maquina_id: recurso.maquina.id) } }

    livres = turnos.sum { |ocorrencia| @calendario.horas_do_setor(ocorrencia, etapas, desde: @agora, maquina_id: recurso.maquina.id) }
    return nova(data, :encerrado) unless livres.positive?

    percentual = [ (ocupadas(recurso.chave, data) / livres * 100).round, 100 ].min
    LinhaDoTempo::CelulaDaCarga.new(data: data, estado: LinhaDoTempo.estado_da_carga(percentual), percentual: percentual)
  end

  def nova(data, estado)
    LinhaDoTempo::CelulaDaCarga.new(data: data, estado: estado)
  end

  # The hours its pieces take that day, every sector's (one agenda).
  def ocupadas(chave, data)
    @ocupadas ||= @fila.pedidos.flat_map { |pedido| @fila.previsao(pedido).vezes }.each_with_object(Hash.new(0.0)) do |vez, horas|
      vez.trechos.each { |trecho| horas[[ vez.recurso, trecho.ocorrencia.data ]] += trecho.horas }
    end
    @ocupadas[[ chave, data ]]
  end
end
