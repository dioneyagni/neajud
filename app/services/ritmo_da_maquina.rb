# What one machine uses in one trabalho (Máquinas 4/5b, decided 24/11/2026,
# canvas "Máquinas", 10–12), in this order:
#   fixada    — "usar a informada" on the machine's page (Q4a: the fix is
#               each machine's): its typed speed;
#   medida    — its own, from its baixas, once it has 5 turnos (RitmoMedido#das_maquinas);
#   da_etapa  — the stage's measured one split by speed, as in 2/5a (the
#               old baixas, with no machine, still count there);
#   informada — nothing measured: its typed speed.
# The Corte do calçado's machines have parameters, not a speed: what they
# use is an aproveitamento, 1.0 (machine time only) when nothing is measured.
#
# Usage: uso = RitmoDaMaquina.em_uso(ritmo, calandra_2.trabalho_de("calandra"), propria: medidas[[ calandra_2.id, "calandra" ]], da_etapa: medidas_da_etapa[%w[tecido calandra]])
#        [ uso.valor, uso.origem ] # => [36.0, :medida]
class RitmoDaMaquina
  EmUso = Struct.new(:valor, :origem, keyword_init: true)

  # ritmo: the stage's RitmoProducao with its machines; trabalho: the
  # machine's TrabalhoDaMaquina; propria, da_etapa: RitmoMedido::Medida or nil.
  def self.em_uso(ritmo, trabalho, propria:, da_etapa:)
    informada = trabalho.corte_por_parametros? ? 1.0 : trabalho.por_hora.to_f
    return EmUso.new(valor: informada, origem: :fixada) if trabalho.fixar_informado
    return EmUso.new(valor: propria.valor.to_f, origem: :medida) if propria
    return EmUso.new(valor: da_etapa.valor.to_f * ritmo.parte_da_maquina(trabalho), origem: :da_etapa) if da_etapa

    EmUso.new(valor: informada, origem: :informada)
  end
end
