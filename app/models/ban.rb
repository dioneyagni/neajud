class Ban < ApplicationRecord
  before_validation :set_uuid, on: :create

  validates :uuid, presence: true, uniqueness: true
  validates :ip_address, presence: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def active?
    expires_at.nil? || expires_at > Time.current
  end

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
