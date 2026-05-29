class Client < ApplicationRecord
  has_many :arquivos, dependent: :nullify
  has_many :modelos, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :responsible, presence: true

  scope :search, ->(q) {
    return all if q.blank?
    where("name LIKE ? OR responsible LIKE ?", "%#{q}%", "%#{q}%")
  }
end
