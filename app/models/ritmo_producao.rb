# How much a stage of a pedido type does per hour (Painel 2/4a, decided
# 05/11/2026): one per type × stage of config/etapas_producao.yml (Q3a), in
# the unit its baixa is given in (m, peças, unidades — Q2a). The dono types
# it; the measured one (RitmoMedido) replaces it once there is enough data,
# unless he fixes his own (Q5a).
#
# Usage: ritmo = RitmoProducao.de("calcado", "impressao") # saved or new
#        ritmo.em_uso(medida) # => 4.6 (the measured) or the typed one
class RitmoProducao < ApplicationRecord
  include GeraUuid

  self.table_name = "ritmos_producao"

  validates :por_hora, numericality: { greater_than: 0, message: "must be more than 0 per hour (blank = not set)" }, allow_nil: true
  validates :etapa, uniqueness: { scope: :tipo }
  validate :etapa_do_tipo

  # Usage: RitmoProducao.de("dtf", "corte")
  def self.de(tipo, etapa)
    find_or_initialize_by(tipo: tipo.to_s, etapa: etapa.to_s)
  end

  def etapa_producao
    EtapasProducao.etapa(tipo, etapa)
  end

  # Usage: ritmo.unidade # => "m/h"
  def unidade
    "#{etapa_producao.unidade_da_medida}/h"
  end

  # medida: RitmoMedido::Medida or nil (too few turnos).
  def em_uso(medida)
    return por_hora if fixar_informado || medida.nil?

    medida.por_hora
  end

  # Usage: ritmo.origem_em_uso(medida) # => "medido", "informado" or nil (none)
  def origem_em_uso(medida)
    return "medido" if medida && !fixar_informado
    return "informado" if por_hora

    nil
  end

  private

  def etapa_do_tipo
    etapa_producao
  rescue EtapasProducao::Invalida => e
    errors.add(:etapa, e.message)
  end
end
