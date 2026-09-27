class ArquivoTimeLog < ApplicationRecord
  belongs_to :arquivo
  belongs_to :user, optional: true

  before_validation :set_uuid, on: :create

  validates :uuid, presence: true, uniqueness: true
  validates :previous_seconds, presence: true
  validates :new_seconds, presence: true

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
