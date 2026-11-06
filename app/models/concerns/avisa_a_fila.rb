# A record the production queue reads (Painel 2/4b, Q5a): a turno, a day off,
# a rhythm, a stock movement (a material in frees a stage). Saved or removed,
# the Painel refreshes itself (CanaisAoVivo.avisar_fila).
# Usage: class Turno < ApplicationRecord; include AvisaAFila; end
module AvisaAFila
  extend ActiveSupport::Concern

  included do
    after_commit -> { CanaisAoVivo.avisar_fila }
  end
end
