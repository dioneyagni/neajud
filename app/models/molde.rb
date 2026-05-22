class Molde < ApplicationRecord
  has_many :stamps, dependent: :nullify

  validates :nome, presence: true, uniqueness: { case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    where("nome LIKE ?", "%#{q}%")
  }

  def to_param
    id.to_s
  end
end
