# Where a stage's pieces may go in the queue (Máquinas 2/5a, decided
# 20–21/11/2026): each active machine doing its trabalho — the queue puts a
# piece on the one that ends it first (Q3a) — or, when the trabalho has no
# machine, the sector itself, one agenda as before the machines (Q7a). A
# machine is one agenda whatever trabalhos it does (Q1a: the Calandra 2's
# calandra and dublagem share its time), so its key is the machine's.
#
# Usage: recursos = RecursosDaFila.new(ritmos, calendario)
#        recursos.do_ritmo(ritmo, "estamparia").map(&:chave) # => ["maquina:3", "maquina:4"]
#        recursos.horas(ocorrencia, "estamparia", [ %w[tecido calandra] ], desde: agora) # => 8.0 (two machines, 4 h)
class RecursosDaFila
  # chave: the agenda's key; maquina, trabalho (its TrabalhoDaMaquina): nil
  # for the sector.
  Recurso = Struct.new(:chave, :maquina, :trabalho, keyword_init: true) do
    def maquina?
      !maquina.nil?
    end
  end

  # ritmos: { [tipo, etapa] => RitmoProducao } with their machines (RitmoProducao.da_fabrica).
  def initialize(ritmos, calendario)
    @ritmos = ritmos
    @calendario = calendario
    @do_ritmo = {}
  end

  # The machines doing the ritmo's trabalho, the first registered first (the
  # tie, Q3a); none, the sector.
  def do_ritmo(ritmo, setor)
    @do_ritmo[[ ritmo.tipo, ritmo.etapa, setor ]] ||=
      if ritmo.com_maquinas?
        ritmo.maquinas.sort_by(&:maquina_id).map do |trabalho|
          Recurso.new(chave: "maquina:#{trabalho.maquina_id}", maquina: trabalho.maquina, trabalho: trabalho)
        end
      else
        [ Recurso.new(chave: setor) ]
      end
  end

  # The sector's resources for those type × stage pairs, each once with the
  # stages it does there: [[recurso, ["calandra"]], …], machines first.
  # Usage: recursos.do_setor("impressao", [ %w[calcado impressao], %w[dtf impressao] ])
  def do_setor(setor, pares)
    mapa = pares.each_with_object({}) do |(tipo, etapa), junto|
      ritmo = @ritmos[[ tipo, etapa ]]
      next unless ritmo

      do_ritmo(ritmo, setor).each { |recurso| (junto[recurso.chave] ||= [ recurso, [] ])[1] |= [ etapa ] }
    end
    mapa.values.sort_by { |recurso, _| [ recurso.maquina? ? 0 : 1, recurso.maquina&.id.to_i ] }
  end

  # The hours the sector has in the turno: each resource's, summed — three
  # machines in a 4 h turno have 12 h. A resource has the most of its
  # stages that work there (CalendarioDeProducao#horas_do_setor).
  def horas(ocorrencia, setor, pares, desde: nil)
    do_setor(setor, pares).sum { |_, etapas| @calendario.horas_do_setor(ocorrencia, etapas, desde: desde) }
  end
end
