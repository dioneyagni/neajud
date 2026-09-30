# Refuses pointing a record at an Excluivel one that is in the trash
# (Etapa 0.4). Only checked when the reference is set or changed, so rows that
# already pointed at it before the deletion stay valid and editable.
#
# Usage:
#   class Molde < ApplicationRecord
#     include ReferenciaAtiva
#     recusa_excluido :client, :modelo
#   end
module ReferenciaAtiva
  extend ActiveSupport::Concern

  class_methods do
    def recusa_excluido(*associacoes)
      associacoes.each { |nome| validate { recusar_referencia_excluida(nome) } }
    end
  end

  private

  def recusar_referencia_excluida(nome)
    foreign_key = self.class.reflect_on_association(nome).foreign_key
    return unless new_record? || will_save_change_to_attribute?(foreign_key)

    registro = public_send(nome)
    return unless registro&.excluido?

    errors.add(nome, "\"#{registro.rotulo_lixeira}\" (id #{registro.id}) is in the trash; expected an active #{nome}")
  end
end
