# Each type × stage's rhythm measured from the baixas (Painel 2/4a, decided
# 05/11/2026, Q5a): over the last 30 days, the measure of the baixas given in
# each turno divided by the turno's hours; the median of those turnos. Only
# turnos that had a baixa of it count, and with fewer than 5 there is no
# measure — the typed rhythm stays. A baixa records when the stage ended,
# not how long it took: one given for a whole pedido at the end of a turno
# makes that turno look fast, so the dono may fix his own (RitmoProducao).
#
# Usage: medidas = RitmoMedido.call(CalendarioDeProducao.new)
#        medidas[%w[calcado impressao]] # => #<Medida por_hora=4.6 turnos=12> or nil
class RitmoMedido
  DIAS = 30
  MINIMO_DE_TURNOS = 5

  Medida = Struct.new(:por_hora, :turnos, keyword_init: true)

  def self.call(calendario, ate: Time.current)
    new(calendario, ate).call
  end

  def initialize(calendario, ate)
    @calendario = calendario
    @ate = ate
    @de = ate - DIAS.days
  end

  # { [tipo, etapa] => Medida } for the ones with enough turnos.
  def call
    ocorrencias = @calendario.ocorrencias(de: @de, ate: @ate)
    baixas.group_by { |baixa| [ baixa.pedido.tipo, baixa.etapa ] }.filter_map do |chave, do_tipo|
      medida = medir(do_tipo, ocorrencias)
      [ chave, medida ] if medida
    end.to_h
  end

  private

  def baixas
    BaixaProducao.vigentes.where(created_at: @de..@ate).includes(:pedido).to_a
  end

  # The baixas outside every turno (given at night, on a day off) don't count.
  def medir(baixas, ocorrencias)
    por_turno = baixas.group_by { |baixa| ocorrencias.find { |ocorrencia| ocorrencia.contem?(baixa.created_at) } }.except(nil)
    return if por_turno.size < MINIMO_DE_TURNOS

    Medida.new(por_hora: mediana(por_turno.map { |ocorrencia, do_turno| do_turno.sum(&:medida) / ocorrencia.horas }).round(3), turnos: por_turno.size)
  end

  def mediana(valores)
    ordenados = valores.sort
    meio = ordenados.size / 2
    ordenados.size.odd? ? ordenados[meio] : (ordenados[meio - 1] + ordenados[meio]) / 2
  end
end
