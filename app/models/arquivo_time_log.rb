class ArquivoTimeLog < ApplicationRecord
  include GeraUuid

  belongs_to :arquivo
  belongs_to :user, optional: true

  validates :previous_seconds, presence: true
  validates :new_seconds, presence: true
end
