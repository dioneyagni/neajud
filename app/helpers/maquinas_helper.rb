module MaquinasHelper
  # The "Por trabalho" table's informado (Máquinas 1/5): the machines' sum;
  # with none, what Ritmos has typed for its stages.
  # ritmos: RitmoProducao.da_fabrica's. Usage: informado_do_trabalho(trabalho, ritmos) # => "80 m/h"
  def informado_do_trabalho(trabalho, ritmos)
    da_etapa = trabalho.etapas.map { |chave| ritmos.fetch(chave) }
    return (da_etapa.first.com_maquinas? ? "pelos parâmetros das máquinas" : "pelos parâmetros de Ritmos") if trabalho.corte_por_parametros?
    return "#{numero_br(da_etapa.first.informado)} #{trabalho.unidade}" if da_etapa.first.com_maquinas?

    da_etapa.map { |ritmo| [ rotulo_da_etapa(ritmo, da_etapa), ritmo.por_hora ? "#{numero_br(ritmo.por_hora)} #{trabalho.unidade}" : "sem ritmo" ].compact.join(" ") }.join(" · ")
  end

  private

  # With two stages, each named: by its tipo ("Calçado", "Tecido") or, of
  # one tipo, by its own name ("Dublagem final").
  def rotulo_da_etapa(ritmo, da_etapa)
    return if da_etapa.size == 1

    da_etapa.map(&:tipo).uniq.size > 1 ? Pedido::ROTULOS_DOS_TIPOS[ritmo.tipo] : ritmo.etapa_producao.nome
  end
end
