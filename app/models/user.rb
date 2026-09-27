# The person's account (the plan's "pessoa"). Access to the empresa comes from
# its Vinculo: a função plus extra accesses (see Autorizacao).
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

  # The vínculo with the instance's empresa (one empresa per instance).
  def vinculo
    vinculos.find_by(empresa: Empresa.atual)
  end

  # What this user may do; without a vínculo, nothing.
  # Usage: user.autorizacao.pode?(:pedidos, :editar)
  def autorizacao
    @autorizacao ||= vinculo&.autorizacao || Autorizacao.new(nil)
  end
end
