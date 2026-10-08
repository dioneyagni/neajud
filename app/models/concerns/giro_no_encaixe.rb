# How a corte's pieces may turn in the fit that gives its meters per piece
# (Etapa 2.2, 1/3; decided 08/10/2026), set on the corte page: "nenhum" (as
# drawn), "180" (default: turned over) or "90" (0°, 90°, 180°, 270° — a
# fabric whose grain allows it). bin/encaixe-dxf.js --giro reads it.
module GiroNoEncaixe
  extend ActiveSupport::Concern

  GIROS = { "nenhum" => "Não pode girar", "180" => "180°", "90" => "90°" }.freeze

  included do
    validates :giro, inclusion: { in: GIROS.keys, message: "%{value} is not a turn; expected nenhum, 180 or 90" }
  end

  # Changes the turn and recomputes the sizes' meters per piece in the
  # background. Usage: corte.definir_giro!("90")
  def definir_giro!(giro)
    update!(giro: giro)
    MetrosPorPecaJob.perform_later(tamanhos.ids, MateriaPrima.larguras_mm, refazer: true)
  end
end
