# A numbering that is never reused (Etapa 2.5a, decided 12/10/2026): DTF-863,
# CR-4114. One row per sequence; each empresa (its own instance) starts at 1.
# The increment is one UPDATE inside the caller's transaction, so two uploads
# at once never take the same number, and a number handed out is gone even
# if its arte changes kind or goes to the trash.
#
# Usage: Sequencia.proximo!("dtf") # => 864
class Sequencia < ApplicationRecord
  validates :nome, presence: true, uniqueness: true

  def self.proximo!(nome)
    transaction do
      find_or_create_by!(nome: nome)
      where(nome: nome).update_all("ultimo = ultimo + 1, updated_at = CURRENT_TIMESTAMP")
      find_by!(nome: nome).ultimo
    end
  end
end
