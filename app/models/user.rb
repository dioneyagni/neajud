# The person's account (the plan's "pessoa"). Access to the empresa comes from
# a Vinculo with perfis; permissions per perfil arrive in Etapa 0.5 (2/3).
class User < ApplicationRecord
  include GeraUuid

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :vinculos, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :nome, presence: true
  validates :password, length: { minimum: 8, maximum: 72 }, allow_nil: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :cloud_user_uuid, uniqueness: true, allow_nil: true

  # The perfis this user has in the instance's empresa (one empresa per
  # instance, see Empresa).
  # Usage: user.perfis # => ["dono"]
  def perfis
    vinculos.find_by(empresa: Empresa.atual)&.perfis || []
  end
end
