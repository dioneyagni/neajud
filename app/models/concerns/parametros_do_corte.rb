# The cutting machine's parameters (Painel 2/4a2, decided 06/11/2026): a
# Corte do calçado's rhythm row (RitmoProducao) and, since Máquinas 1/5
# (Q8a), each machine that does it (TrabalhoDaMaquina). Blank = PADRAO.
#   velocidade_mm_s        — the knife along the cut line
#   pinca_s                — the punch, per hole
#   preparo_min            — per meter of fabric cut
#   recolhimento_pecas_min — pieces gathered per minute
#   troca_min              — each change of material, in the pedido and
#                            between pedidos in a row (the queue, 2/4b)
#
# Usage: ritmo.parametro_do_corte(:pinca_s) # => 2.0 (the default when blank)
module ParametrosDoCorte
  extend ActiveSupport::Concern

  PADRAO = { velocidade_mm_s: 100, pinca_s: 2, preparo_min: 5, recolhimento_pecas_min: 50, troca_min: 10 }.freeze
  # How a machine's page names them (Máquinas 1/5): [name, unit].
  ROTULOS = { velocidade_mm_s: [ "Faca", "mm/s" ], pinca_s: [ "Pinça por furo", "s" ], preparo_min: [ "Preparo por metro", "min" ],
              recolhimento_pecas_min: [ "Recolhimento", "peças/min" ], troca_min: [ "Troca de material", "min" ] }.freeze

  included do
    validates(*PADRAO.keys, numericality: { greater_than: 0, message: "must be more than 0 (blank = the default)" }, allow_nil: true)
  end

  def parametro_do_corte(campo)
    (self[campo] || PADRAO.fetch(campo)).to_f
  end
end
