# Each type × stage's rhythm measured from the baixas (Painel 2/4a, decided
# 05/11/2026, Q5a): over the last 30 days, the measure of the baixas given in
# each turno divided by the turno's hours; the median of those turnos. Only
# turnos that had a baixa of it count, and with fewer than 5 there is no
# measure — the typed rhythm stays. A baixa records when the stage ended,
# not how long it took: one given for a whole pedido at the end of a turno
# makes that turno look fast, so the dono may fix his own (RitmoProducao).
#
# A stage whose rhythm counts something else (Painel 2/4a2, decided
# 06/11/2026) measures that from the baixa's lines: the calçado's
# Estamparia their paper's meters (m/h); its Corte the cutting machine's
# time (TempoDoCorte), so the measure is its aproveitamento — 0.62 when the
# machine's work took 62% of the turno.
#
# Usage: medidas = RitmoMedido.call(CalendarioDeProducao.new)
#        medidas[%w[calcado impressao]] # => #<Medida valor=4.6 turnos=12> or nil
class RitmoMedido
  DIAS = 30
  MINIMO_DE_TURNOS = 5

  # valor: per hour in the rhythm's unit; the aproveitamento for a machine.
  Medida = Struct.new(:valor, :turnos, keyword_init: true)

  # ritmos: the saved rhythms (the machine's parameters); read when not given.
  def self.call(calendario, ate: Time.current, ritmos: nil)
    new(calendario, ate, ritmos).call
  end

  def initialize(calendario, ate, ritmos)
    @calendario = calendario
    @ate = ate
    @de = ate - DIAS.days
    @ritmos = (ritmos || RitmoProducao.all).index_by { |ritmo| [ ritmo.tipo, ritmo.etapa ] }
    @linhas = {}
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

    Medida.new(valor: mediana(por_turno.map { |ocorrencia, do_turno| do_turno.sum { |baixa| carga(baixa) } / ocorrencia.horas }).round(3), turnos: por_turno.size)
  end

  # What a baixa did, in its rhythm's unit.
  def carga(baixa)
    etapa = EtapasProducao.etapa(baixa.pedido.tipo, baixa.etapa)
    case etapa.ritmo
    when "papel" then linhas_da(baixa, etapa.dup.tap { |em_papel| em_papel.esperado = "papel" }).sum { |linha| linha.esperado.to_f }
    when "maquina_de_corte" then TempoDoCorte.call(linhas_da(baixa, etapa), ritmo_de(baixa)).horas
    else baixa.medida
    end
  end

  # The pedido's lines of the stage that the baixa covered, built once.
  def linhas_da(baixa, etapa)
    todas = @linhas[[ baixa.pedido_id, etapa.chave, etapa.esperado ]] ||= LinhasDeProducao.call(baixa.pedido, etapa)
    todas.select { |linha| baixa.linhas.include?(linha.chave) }
  end

  def ritmo_de(baixa)
    @ritmos[[ baixa.pedido.tipo, baixa.etapa ]] || RitmoProducao.new(tipo: baixa.pedido.tipo, etapa: baixa.etapa)
  end

  def mediana(valores)
    ordenados = valores.sort
    meio = ordenados.size / 2
    ordenados.size.odd? ? ordenados[meio] : (ordenados[meio - 1] + ordenados[meio]) / 2
  end
end
