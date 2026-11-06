# How much a stage of a pedido type does per hour (Painel 2/4a, decided
# 05/11/2026): one per type × stage of config/etapas_producao.yml (Q3a), in
# the unit its baixa is given in (m, peças, unidades — Q2a). The dono types
# it; the measured one (RitmoMedido) replaces it once there is enough data,
# unless he fixes his own (Q5a).
#
# A stage may count something else (config/etapas_producao.yml `ritmo`,
# Painel 2/4a2): the calçado's Estamparia its paper's meters; its Corte is
# the cutting machine's time (MAQUINA_PADRAO), the measured one then its
# aproveitamento — that time over the turno's.
#
# Usage: ritmo = RitmoProducao.de("calcado", "impressao") # saved or new
#        ritmo.em_uso(medida) # => 4.6 (the measured) or the typed one
class RitmoProducao < ApplicationRecord
  include GeraUuid
  include AvisaAFila

  self.table_name = "ritmos_producao"

  # The cutting machine's parameters (Painel 2/4a2, decided 06/11/2026), for
  # a stage whose rhythm is maquina_de_corte; blank = this default.
  #   velocidade_mm_s        — the knife along the cut line
  #   pinca_s                — the punch, per hole
  #   preparo_min            — per meter of fabric cut
  #   recolhimento_pecas_min — pieces gathered per minute
  #   troca_min              — each change of material, in the pedido and
  #                            between pedidos in a row (the queue, 2/4b)
  MAQUINA_PADRAO = { velocidade_mm_s: 100, pinca_s: 2, preparo_min: 5, recolhimento_pecas_min: 50, troca_min: 10 }.freeze

  validates :por_hora, numericality: { greater_than: 0, message: "must be more than 0 per hour (blank = not set)" }, allow_nil: true
  validates(*MAQUINA_PADRAO.keys, numericality: { greater_than: 0, message: "must be more than 0 (blank = the default)" }, allow_nil: true)
  validates :etapa, uniqueness: { scope: :tipo }
  validate :etapa_do_tipo

  # Usage: RitmoProducao.de("dtf", "corte")
  def self.de(tipo, etapa)
    find_or_initialize_by(tipo: tipo.to_s, etapa: etapa.to_s)
  end

  def etapa_producao
    EtapasProducao.etapa(tipo, etapa)
  end

  # Usage: ritmo.unidade # => "m/h" (the calçado's Estamparia too: its paper)
  def unidade
    etapa_producao.ritmo == "papel" ? "m/h" : "#{etapa_producao.unidade_da_medida}/h"
  end

  # Is its time the cutting machine's (TempoDoCorte) rather than per hour?
  def maquina_de_corte?
    etapa_producao.ritmo == "maquina_de_corte"
  end

  # A machine parameter, the default when blank. Usage: ritmo.maquina(:pinca_s) # => 2.0
  def maquina(campo)
    (self[campo] || MAQUINA_PADRAO.fetch(campo)).to_f
  end

  # medida: RitmoMedido::Medida or nil (too few turnos). The machine's is
  # its aproveitamento: 1.0 (machine time only) unless measured.
  def em_uso(medida)
    return (fixar_informado || medida.nil? ? 1.0 : medida.valor) if maquina_de_corte?
    return por_hora if fixar_informado || medida.nil?

    medida.valor
  end

  # The hours a load (CargaDaEtapa) takes at the rhythm in use (Painel 2/4b);
  # nil without a rhythm (Q2a). The machine's load is already hours, over
  # its aproveitamento.
  # Usage: ritmo.horas(12.0, medida) # => 2.4 at 5 m/h
  def horas(carga, medida)
    em_uso = em_uso(medida)
    em_uso && carga.to_f / em_uso.to_f
  end

  # Usage: ritmo.origem_em_uso(medida) # => "medido", "informado" or nil (none)
  def origem_em_uso(medida)
    return "medido" if medida && !fixar_informado
    return "informado" if por_hora || maquina_de_corte?

    nil
  end

  private

  def etapa_do_tipo
    etapa_producao
  rescue EtapasProducao::Invalida => e
    errors.add(:etapa, e.message)
  end
end
