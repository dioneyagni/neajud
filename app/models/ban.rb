class Ban < ApplicationRecord
  include GeraUuid

  validates :ip_address, presence: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def active?
    expires_at.nil? || expires_at > Time.current
  end
end
