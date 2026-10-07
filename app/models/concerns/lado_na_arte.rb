# The side of a file of a mirrored part (Etapa 1.2, 3/3 parte 3c, decided
# 06/10/2026): a part the molde marks espelhada (molde_pecas.espelhada) may
# have one file for the right and one for the left. nil = no side: it serves
# both (the printer mirrors it) until the arte has a file with a side in that
# size — then both are needed (decided 07/10/2026; ResolucaoDoItem).
module LadoNaArte
  extend ActiveSupport::Concern

  LADOS = %w[direito esquerdo].freeze
  # How the team writes it in file names (decided 07/10/2026: "…-29_30-ESQ").
  ABREVIACOES = { "direito" => "DIR", "esquerdo" => "ESQ" }.freeze

  included do
    validates :lado, inclusion: { in: LADOS, allow_nil: true, message: "%{value} is not a side; expected direito or esquerdo" }
  end

  # Usage: arquivo.lado_abreviado # => "ESQ"
  def lado_abreviado
    ABREVIACOES[lado]
  end

  # Is this file's part mirrored in its molde (so a side makes sense)?
  # Usage: arquivo.parte_espelhada? # => true for a Lateral marked espelhada
  def parte_espelhada?
    return false unless molde && resolved_peca

    molde.molde_pecas.exists?(peca: resolved_peca, espelhada: true)
  end
end
