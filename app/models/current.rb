class Current < ActiveSupport::CurrentAttributes
  attribute :session
  # RedeDeDublagens.atual: the dublagem network, read once per request or job.
  attribute :rede_de_dublagens
  delegate :user, to: :session, allow_nil: true
end
