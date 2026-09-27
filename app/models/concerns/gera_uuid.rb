# Fills `uuid` on create — every new entity gets one (docs/plano.md: UUID on
# every entity, Etapa 1.1).
# Usage: class Empresa < ApplicationRecord; include GeraUuid; end
module GeraUuid
  extend ActiveSupport::Concern

  included do
    before_validation :gerar_uuid, on: :create
    validates :uuid, presence: true, uniqueness: true
  end

  private

  def gerar_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
