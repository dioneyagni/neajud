# Lets forms and fetch calls point at another record by its uuid, never by the
# integer id (Etapa 1.1, 1/2). `atribui_por_uuid :client` adds `client_uuid`
# and `client_uuid=`; a blank value unlinks, an unknown one raises
# RecordNotFound (404) instead of linking nothing.
#
# Why not keep `client_id` with a uuid value: Rails casts "8f3a…" to the
# integer 8 without complaint, which would silently link the wrong record.
#
# Usage: class Modelo < ApplicationRecord; atribui_por_uuid :client, :molde; end
#        Modelo.new(nome: "X", client_uuid: params[:client_uuid])
module AtribuiPorUuid
  extend ActiveSupport::Concern

  class_methods do
    def atribui_por_uuid(*associacoes)
      associacoes.each { |associacao| definir_atribuicao_por_uuid(associacao) }
    end

    private

    def definir_atribuicao_por_uuid(associacao)
      classe = reflect_on_association(associacao)&.klass
      raise ArgumentError, "#{name} has no belongs_to #{associacao.inspect}; expected one of #{reflect_on_all_associations(:belongs_to).map(&:name)}" unless classe

      define_method(:"#{associacao}_uuid") { public_send(associacao)&.uuid }
      define_method(:"#{associacao}_uuid=") do |uuid|
        public_send(:"#{associacao}=", uuid.presence && classe.por_uuid!(uuid))
      end
    end
  end
end
