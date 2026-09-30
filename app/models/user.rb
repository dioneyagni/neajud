# The person's account (the plan's "pessoa"). Access to the empresa comes from
# its Vinculo: a função plus extra accesses (see Autorizacao).
class User < ApplicationRecord
  include GeraUuid

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :vinculos, dependent: :destroy
  belongs_to :desativado_por, class_name: "User", optional: true

  scope :ativos, -> { where(desativado_em: nil) }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :nome, presence: true
  validates :password, length: { minimum: 8, maximum: 72 }, allow_nil: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :cloud_user_uuid, uniqueness: true, allow_nil: true

  # The vínculo with the instance's empresa (one empresa per instance).
  def vinculo
    vinculos.find_by(empresa: Empresa.atual)
  end

  def ativo?
    desativado_em.nil?
  end

  # Blocks sign-in and ends every open session; the person stays in lists
  # and history (nothing is deleted — docs/plano.md).
  # Usage: user.desativar!(por: Current.user)
  def desativar!(por:)
    transaction do
      update_columns(desativado_em: Time.current, desativado_por_id: por&.id)
      sessions.destroy_all
    end
  end

  def reativar!
    update_columns(desativado_em: nil, desativado_por_id: nil)
  end

  # Set by whoever manages users; the person must change it at the next
  # sign-in, and open sessions end now.
  # Usage: user.definir_senha_provisoria!("temporaria-123")
  def definir_senha_provisoria!(senha)
    transaction do
      update!(password: senha, trocar_senha: true)
      sessions.destroy_all
    end
  end

  # Usage: user.trocar_senha!("nova-senha-segura")
  def trocar_senha!(nova)
    update!(password: nova, trocar_senha: false)
  end

  # What this user may do; without a vínculo, nothing.
  # Usage: user.autorizacao.pode?(:pedidos, :editar)
  def autorizacao
    @autorizacao ||= vinculo&.autorizacao || Autorizacao.new(nil)
  end
end
