# The stops a sector's queue shows (Máquinas 3/5b, decided 24–25/11/2026,
# canvas "Máquinas", 8): which machines stop in the first turno ahead and
# by which stop — its lane says "parada até qui 26/11", the header counts
# them —, and the pieces that wait for one (Q2a: held there, or started on
# it), which say so. A stop that came back to work no longer counts.
#
# Usage: paradas = ParadasNaFila.new(fila)
#        paradas.da_maquina(calandra_2)&.nome # => "Manutenção da Calandra 2"
#        paradas.espera(vez) # => :presa, :comecada or nil
class ParadasNaFila
  def initialize(fila)
    @fila = fila
    @da_maquina = {}
  end

  # The stop taking the machine in the first turno ahead, or nil.
  def da_maquina(maquina)
    return unless maquina

    @da_maquina.fetch(maquina.id) { @da_maquina[maquina.id] = procurar(maquina) }
  end

  # Usage: paradas.quantas(maquinas) # => 1
  def quantas(maquinas)
    maquinas.count { |maquina| da_maquina(maquina) }
  end

  # Why the piece waits for its stopped machine: :comecada (its baixa's
  # machine, 4/5a) or :presa (held there, 2/5b); nil when it doesn't.
  def espera(vez)
    return unless da_maquina(vez.maquina)
    return :comecada if vez.maquina_da_baixa == vez.maquina.id

    :presa if vez.fixacao&.para_maquina_id == vez.maquina.id
  end

  private

  def procurar(maquina)
    ocorrencia = @fila.ocorrencias.first
    return unless ocorrencia

    etapas = maquina.trabalhos.flat_map { |feito| feito.tipo_de_trabalho.etapas.map(&:last) }.uniq
    @fila.calendario.paradas(ocorrencia, etapas, maquina_id: maquina.id).reject(&:voltou_em).min_by(&:data_fim)
  end
end
