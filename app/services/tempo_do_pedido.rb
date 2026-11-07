# The faixa's own timeline of one pedido (Painel 2/4c, Q5a; the axis of
# Q16a, 04/11/2026): a lane per stage of its path, a column per turno from
# now to its previsão, each stage's pieces in the queue (FilaDeProducao)
# filling the turnos they take. A stage done is marked done; one without
# previsão says why. A cliente final gets a column per day (Q4a).
#
# What was programmed (dashed), the arrows of a virada and "who crossed it"
# come with the programação (3/4): nothing is stored to draw them yet.
#
# Usage: tempo = TempoDoPedido.call(linha, fila: painel.fila)
#        tempo.colunas.map(&:nome)                     # => ["Manhã", "Tarde", "Manhã"]
#        tempo.raias.map { |r| [ r.etapa.chave, r.estado ] } # => [["impressao", :feita], ["calandra", :prevista]]
#        tempo.raias.last.celulas                      # => [nil, 0.5, 1.0]
class TempoDoPedido
  # More than this many turnos: the rest is said, not drawn.
  COLUNAS = 24

  # inicio / fim: the turno's (or the day's) hours.
  Coluna = Struct.new(:data, :nome, :inicio, :fim, :agora, :depois_do_prazo, keyword_init: true) do
    def horas
      (fim - inicio) / 3600.0
    end
  end
  # estado: :feita, :prevista, :andamento (some line had its baixa), :sem_previsao.
  # celulas: per column, the share of it the stage fills (nil: none).
  Raia = Struct.new(:etapa, :estado, :vez, :celulas, keyword_init: true)

  # nil when the pedido has nothing ahead in the queue.
  def self.call(linha, fila:, cliente_final: false)
    previsao = linha.previsao
    return if previsao.nil? || previsao.vezes.none? { |vez| vez.trechos.any? }

    new(linha, previsao, fila, cliente_final)
  end

  attr_reader :colunas, :raias, :restantes

  def initialize(linha, previsao, fila, cliente_final)
    @linha, @fila, @cliente_final = linha, fila, cliente_final
    @vezes = previsao.vezes.index_by { |vez| vez.etapa.chave }
    todas = cliente_final ? por_dia(ocorrencias) : por_turno(ocorrencias)
    @colunas = todas.first(COLUNAS)
    @restantes = todas.size - @colunas.size
    @raias = linha.caminho.flatten.map { |etapa| raia(etapa) }
  end

  private

  # The turnos from the one under way (or the next) to its last piece.
  def ocorrencias
    trechos = @vezes.values.flat_map(&:trechos)
    ate = trechos.map(&:fim).max
    @fila.ocorrencias.select { |ocorrencia| ocorrencia.fim > @fila.agora && ocorrencia.inicio < ate }
  end

  def por_turno(ocorrencias)
    ocorrencias.map do |ocorrencia|
      Coluna.new(data: ocorrencia.data, nome: ocorrencia.turno.nome, inicio: ocorrencia.inicio, fim: ocorrencia.fim,
                 agora: ocorrencia.contem?(@fila.agora), depois_do_prazo: depois_do_prazo?(ocorrencia.data))
    end
  end

  def por_dia(ocorrencias)
    ocorrencias.group_by(&:data).map do |data, do_dia|
      Coluna.new(data: data, inicio: do_dia.map(&:inicio).min, fim: do_dia.map(&:fim).max,
                 agora: data == @fila.agora.to_date, depois_do_prazo: depois_do_prazo?(data))
    end
  end

  def depois_do_prazo?(data)
    @linha.prazo.present? && data > @linha.prazo
  end

  def raia(etapa)
    vez = @vezes[etapa.chave]
    return Raia.new(etapa: etapa, estado: :feita, celulas: []) unless vez
    return Raia.new(etapa: etapa, estado: :sem_previsao, vez: vez, celulas: []) unless vez.fim

    Raia.new(etapa: etapa, estado: vez.iniciada? ? :andamento : :prevista, vez: vez, celulas: colunas.map { |coluna| parte(vez, coluna) })
  end

  # The share of the column the stage's pieces fill.
  def parte(vez, coluna)
    horas = vez.trechos.sum { |trecho| [ [ trecho.fim, coluna.fim ].min - [ trecho.inicio, coluna.inicio ].max, 0 ].max } / 3600.0
    horas.positive? ? [ horas / coluna.horas, 1.0 ].min.round(2) : nil
  end
end
