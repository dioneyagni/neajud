# Fills `uuid` on create — every new entity gets one (docs/plano.md: UUID on
# every entity, Etapa 1.1) — and makes it the record's public identifier:
# `to_param` is the uuid, so every URL helper builds /clients/<uuid>, never the
# integer id (which stays the internal key).
# Usage: class Empresa < ApplicationRecord; include GeraUuid; end
#        Client.por_uuid!(params[:id])
module GeraUuid
  extend ActiveSupport::Concern

  included do
    before_validation :gerar_uuid, on: :create
    validates :uuid, presence: true, uniqueness: true
  end

  class_methods do
    # Lookup by the public identifier; 404 (RecordNotFound) when unknown.
    def por_uuid!(uuid)
      find_by!(uuid: uuid.to_s)
    end
  end

  def to_param
    uuid
  end

  private

  def gerar_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
