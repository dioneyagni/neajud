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
# Máquinas 1/5 (decided 20/11/2026): a stage whose trabalho has machines
# takes their sum as its informado (Q7a: none, as before); the Corte do
# calçado each machine's parameters (Q8a). The measured one is unchanged.
#
# Usage: ritmo = RitmoProducao.de("calcado", "impressao") # saved or new
#        ritmo.em_uso(medida) # => 4.6 (the measured) or the typed one
class RitmoProducao < ApplicationRecord
  include GeraUuid
  include AvisaAFila
  include ParametrosDoCorte

  self.table_name = "ritmos_producao"

  # The cutting machine's parameters (Painel 2/4a2), for a stage whose
  # rhythm is maquina_de_corte: ParametrosDoCorte::PADRAO, its notes there.
  MAQUINA_PADRAO = ParametrosDoCorte::PADRAO

  # The active machines' TrabalhoDaMaquina rows for its trabalho (Máquinas
  # 1/5), set by da_fabrica in one query; read on demand otherwise.
  attr_writer :maquinas

  validates :por_hora, numericality: { greater_than: 0, message: "must be more than 0 per hour (blank = not set)" }, allow_nil: true
  validates :etapa, uniqueness: { scope: :tipo }
  validate :etapa_do_tipo

  # Usage: RitmoProducao.de("dtf", "corte")
  def self.de(tipo, etapa)
    find_or_initialize_by(tipo: tipo.to_s, etapa: etapa.to_s)
  end

  # Every type × stage's ritmo, saved or new, its machines read in one query.
  # salvos: the saved rows (a page's visible ones; the queue's given ones).
  # Usage: RitmoProducao.da_fabrica[%w[tecido calandra]].informado # => 80.0 (two machines of 40)
  def self.da_fabrica(salvos = all.to_a, trabalhos: TrabalhoDaMaquina.ativos)
    por_trabalho = trabalhos.includes(:maquina).group_by(&:trabalho)
    por_chave = salvos.index_by { |ritmo| [ ritmo.tipo, ritmo.etapa ] }
    EtapasProducao.todas.flat_map { |tipo, etapas| etapas.map { |etapa| [ tipo, etapa.chave ] } }.uniq.to_h do |chave|
      ritmo = por_chave[chave] || new(tipo: chave[0], etapa: chave[1])
      ritmo.maquinas = por_trabalho.fetch(ritmo.trabalho_de_maquina&.chave, [])
      [ chave, ritmo ]
    end
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

  # The machine trabalho that does this stage (TrabalhosDeMaquina), nil for the Conferência.
  def trabalho_de_maquina
    TrabalhosDeMaquina.da_etapa(tipo, etapa)
  end

  def maquinas
    @maquinas ||= trabalho_de_maquina ? TrabalhoDaMaquina.ativos.includes(:maquina).where(trabalho: trabalho_de_maquina.chave).to_a : []
  end

  def com_maquinas?
    maquinas.any?
  end

  # The informado (Máquinas 1/5, Q7a): the sum of its trabalho's machines
  # when it has any — then typed in Máquinas, not here —, else the one typed.
  # The Corte do calçado's machines have parameters, not a speed: nil.
  # Usage: ritmo.informado # => 80.0
  def informado
    return por_hora unless com_maquinas?
    return if maquina_de_corte?

    maquinas.sum { |feito| feito.por_hora.to_d }
  end

  # Whose parameters the cutting machine's time uses (TempoDoCorte): each of
  # the Corte do calçado's machines (Q8a), else this row's.
  def fontes_do_corte
    com_maquinas? ? maquinas : [ self ]
  end

  # medida: RitmoMedido::Medida or nil (too few turnos). The machine's is
  # its aproveitamento: 1.0 (machine time only) unless measured.
  def em_uso(medida)
    return (fixar_informado || medida.nil? ? 1.0 : medida.valor) if maquina_de_corte?
    return informado if fixar_informado || medida.nil?

    medida.valor
  end

  # The hours a load (CargaDaEtapa) takes at the rhythm in use (Painel 2/4b);
  # nil without a rhythm (Q2a). The machine's load is already hours, over
  # its aproveitamento. parte: one machine's share of the rhythm (Máquinas
  # 2/5a, parte_da_maquina) — the load goes to it alone.
  # Usage: ritmo.horas(12.0, medida) # => 2.4 at 5 m/h
  #        ritmo.horas(24.0, nil, parte: 0.5) # => 0.6 on one of two machines of 40 m/h
  def horas(carga, medida, parte: 1.0)
    em_uso = em_uso(medida)
    em_uso && carga.to_f / (em_uso.to_f * parte)
  end

  # A machine's share of the rhythm in use (Máquinas 2/5a, assumed 21/11/2026):
  # its speed over the machines' sum, so the measured one — still per stage
  # until the baixa says the machine (4/5) — splits like the informado. A
  # cutting machine's load is already its own time: 1.
  # Usage: ritmo.parte_da_maquina(calandra_2.trabalho_de("calandra")) # => 0.5 (40 of 80 m/h)
  def parte_da_maquina(trabalho)
    return 1.0 if maquina_de_corte?

    trabalho.por_hora.to_f / informado.to_f
  end

  # Usage: ritmo.origem_em_uso(medida) # => "medido", "informado" or nil (none)
  def origem_em_uso(medida)
    return "medido" if medida && !fixar_informado
    return "informado" if informado || maquina_de_corte?

    nil
  end

  private

  def etapa_do_tipo
    etapa_producao
  rescue EtapasProducao::Invalida => e
    errors.add(:etapa, e.message)
  end
end
