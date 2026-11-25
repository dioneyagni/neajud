# What each machine measured and uses, for the pages that show it (Máquinas
# 4/5b, canvas "Máquinas", 10–12): the Máquinas list (a row per machine ×
# trabalho), a machine's page and Ritmos (a stage's machines summed). The
# queue asks RitmoDaMaquina itself; this only gathers it for reading.
#
# A trabalho may do two stages (the Impressão em papel's calçado and
# tecido): its own measure is one, but what it uses from the stage's is per
# stage — `usos` has one per stage.
#
# Usage: uso = UsoDasMaquinas.new(RitmoProducao.da_fabrica, RitmoMedido.new(calendario))
#        linha = uso.do_trabalho(calandra_2.trabalho_de("calandra"))
#        [ linha.medida&.valor, linha.faltam, linha.usos.map { |u| u.em_uso.origem } ] # => [36.0, 0, [:medida]]
#        uso.da_etapa(ritmo).map(&:maquina) # => the stage's machines with what each uses there
class UsoDasMaquinas
  # medida: its own (RitmoMedido::Medida) or nil; faltam: turnos to 5;
  # usos: [Uso] one per stage of the trabalho.
  Linha = Struct.new(:trabalho, :medida, :faltam, :usos, keyword_init: true)
  # ritmo: the stage's RitmoProducao; em_uso: RitmoDaMaquina::EmUso.
  Uso = Struct.new(:ritmo, :trabalho, :em_uso, keyword_init: true) do
    def maquina = trabalho.maquina
  end

  # ritmos: { [tipo, etapa] => RitmoProducao } (RitmoProducao.da_fabrica); medido: a RitmoMedido.
  def initialize(ritmos, medido)
    @ritmos = ritmos
    @medido = medido
  end

  # Usage: uso.do_trabalho(trabalho_da_maquina).faltam # => 3
  def do_trabalho(trabalho)
    medida = @medido.das_maquinas[[ trabalho.maquina_id, trabalho.trabalho ]]
    faltam = medida ? 0 : RitmoMedido::MINIMO_DE_TURNOS - @medido.turnos_da_maquina(trabalho.maquina_id, trabalho.trabalho)
    Linha.new(trabalho: trabalho, medida: medida, faltam: faltam, usos: etapas_de(trabalho).map { |ritmo| uso(ritmo, trabalho, medida) })
  end

  # The stage's machines, each with what it uses there.
  def da_etapa(ritmo)
    ritmo.maquinas.sort_by(&:maquina_id).map { |trabalho| uso(ritmo, trabalho, @medido.das_maquinas[[ trabalho.maquina_id, trabalho.trabalho ]]) }
  end

  # The stage's machines with their own measure, in machine order.
  def medidas_da_etapa(ritmo)
    ritmo.maquinas.sort_by(&:maquina_id).filter_map { |trabalho| @medido.das_maquinas[[ trabalho.maquina_id, trabalho.trabalho ]] }
  end

  private

  def etapas_de(trabalho)
    trabalho.tipo_de_trabalho.etapas.filter_map { |chave| @ritmos[chave] }
  end

  def uso(ritmo, trabalho, medida)
    Uso.new(ritmo: ritmo, trabalho: trabalho, em_uso: RitmoDaMaquina.em_uso(ritmo, trabalho, propria: medida, da_etapa: @medido.call[[ ritmo.tipo, ritmo.etapa ]]))
  end
end
