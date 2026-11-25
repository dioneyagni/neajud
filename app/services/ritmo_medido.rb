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
# Máquinas 4/5b (decided 24–25/11/2026): each machine × trabalho is measured
# too, from the baixas that say the machine (4/5a) — its stages together
# (the Impressão em papel's calçado and tecido). A machine doing two
# trabalhos in one turno splits the turno's hours between them by the time
# each took at its informada (Q1a), so neither looks slow. The old baixas,
# with no machine, count only in the stage's.
#
# Usage: medidas = RitmoMedido.call(CalendarioDeProducao.new)
#        medidas[%w[calcado impressao]] # => #<Medida valor=4.6 turnos=12> or nil
#        RitmoMedido.new(calendario).das_maquinas[[ calandra_2.id, "calandra" ]] # => #<Medida valor=36.0 turnos=6>
class RitmoMedido
  DIAS = 30
  MINIMO_DE_TURNOS = 5

  # valor: per hour in the rhythm's unit; the aproveitamento for a machine.
  Medida = Struct.new(:valor, :turnos, keyword_init: true)

  # ritmos: the saved rhythms (the machine's parameters); read when not given.
  def self.call(calendario, ate: Time.current, ritmos: nil)
    new(calendario, ate: ate, ritmos: ritmos).call
  end

  def initialize(calendario, ate: Time.current, ritmos: nil)
    @calendario = calendario
    @ate = ate
    @de = ate - DIAS.days
    @ritmos = ritmos ? ritmos.index_by { |ritmo| [ ritmo.tipo, ritmo.etapa ] } : RitmoProducao.da_fabrica
    @linhas = {}
  end

  # { [tipo, etapa] => Medida } for the ones with enough turnos.
  def call
    @call ||= baixas.group_by { |baixa| [ baixa.pedido.tipo, baixa.etapa ] }.filter_map do |chave, do_tipo|
      medida = mediana_dos_turnos(por_turno(do_tipo).map { |ocorrencia, do_turno| do_turno.sum { |baixa| carga(baixa) } / ocorrencia.horas })
      [ chave, medida ] if medida
    end.to_h
  end

  # { [maquina_id, trabalho] => Medida } for the machines' trabalhos with
  # enough turnos (Máquinas 4/5b).
  def das_maquinas
    @das_maquinas ||= valores_das_maquinas.filter_map do |chave, valores|
      medida = mediana_dos_turnos(valores)
      [ chave, medida ] if medida
    end.to_h
  end

  # The turnos a machine's trabalho has a baixa in, enough or not ("faltam 3 turnos").
  def turnos_da_maquina(maquina_id, trabalho)
    valores_das_maquinas.fetch([ maquina_id, trabalho ], []).size
  end

  private

  def baixas
    @baixas ||= BaixaProducao.vigentes.where(created_at: @de..@ate).includes(:pedido, maquina: :trabalhos).to_a
  end

  # The baixas outside every turno (given at night, on a day off) don't count.
  def por_turno(baixas)
    @ocorrencias ||= @calendario.ocorrencias(de: @de, ate: @ate)
    baixas.group_by { |baixa| @ocorrencias.find { |ocorrencia| ocorrencia.contem?(baixa.created_at) } }.except(nil)
  end

  def mediana_dos_turnos(valores)
    return if valores.size < MINIMO_DE_TURNOS

    Medida.new(valor: mediana(valores).round(3), turnos: valores.size)
  end

  # { [maquina_id, trabalho] => [one value per turno] }: per machine and
  # turno, each trabalho's load over its share of the turno's hours.
  def valores_das_maquinas
    return @valores_das_maquinas if @valores_das_maquinas

    feitas = baixas.select { |baixa| feito_na_maquina(baixa) }
    @valores_das_maquinas = feitas.group_by(&:maquina_id).each_with_object(Hash.new { |valores, chave| valores[chave] = [] }) do |(maquina_id, da_maquina), valores|
      por_turno(da_maquina).each do |ocorrencia, do_turno|
        repartir(ocorrencia, do_turno).each { |trabalho, valor| valores[[ maquina_id, trabalho ]] << valor }
      end
    end
  end

  # { trabalho => load per hour } of one machine's turno (Q1a).
  def repartir(ocorrencia, baixas)
    cargas = baixas.group_by { |baixa| feito_na_maquina(baixa) }.to_h { |feito, do_trabalho| [ feito, do_trabalho.sum { |baixa| carga(baixa, fonte: feito) } ] }
    tempos = cargas.to_h { |feito, carga| [ feito, feito.corte_por_parametros? ? carga : carga / feito.por_hora.to_f ] }
    total = tempos.values.sum
    cargas.filter_map do |feito, carga|
      horas = total.positive? ? ocorrencia.horas * tempos[feito] / total : ocorrencia.horas
      [ feito.trabalho, carga / horas ] if horas.positive?
    end.to_h
  end

  # The machine's TrabalhoDaMaquina for the baixa's stage; nil when the
  # baixa has no machine or the machine no longer does it.
  def feito_na_maquina(baixa)
    trabalho = baixa.maquina && TrabalhosDeMaquina.da_etapa(baixa.pedido.tipo, baixa.etapa)
    trabalho && baixa.maquina.trabalho_de(trabalho.chave)
  end

  # What a baixa did, in its rhythm's unit (CargaDaEtapa); fonte: the
  # machine whose cutting parameters count (Máquinas 4/5b), else the ritmo's.
  def carga(baixa, fonte: nil)
    etapa = EtapasProducao.etapa(baixa.pedido.tipo, baixa.etapa)
    return baixa.medida if etapa.ritmo.nil?

    CargaDaEtapa.call(baixa.pedido, etapa, linhas_da(baixa, etapa), ritmo_de(baixa), memoria: @linhas, fonte: fonte).valor
  end

  # The pedido's lines of the stage that the baixa covered, built once.
  def linhas_da(baixa, etapa)
    todas = @linhas[[ baixa.pedido_id, etapa.chave ]] ||= LinhasDeProducao.call(baixa.pedido, etapa)
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
