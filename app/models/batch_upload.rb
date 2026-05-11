class BatchUpload < ApplicationRecord
  has_many :stamps, foreign_key: :batch_id, primary_key: :uuid

  before_validation :set_uuid, on: :create

  validates :uuid, presence: true, uniqueness: true

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end