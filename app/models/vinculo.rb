# A user's access to the empresa: one or more fixed perfis whose permissions
# add up (docs/plano.md, "Usuários e permissões"). The table of what each
# perfil may do is enforced in Etapa 0.5 (2/3).
class Vinculo < ApplicationRecord
  include GeraUuid

  PERFIS = %w[dono admin atendimento designer producao cliente_final].freeze

  belongs_to :user
  belongs_to :empresa

  validates :user_id, uniqueness: { scope: :empresa_id }
  validate :perfis_conhecidos

  private

  def perfis_conhecidos
    return errors.add(:perfis, "must have at least one perfil; expected some of #{PERFIS.join(", ")}") if perfis.blank?

    desconhecidos = perfis - PERFIS
    errors.add(:perfis, "has unknown #{desconhecidos.inspect}; expected some of #{PERFIS.join(", ")}") if desconhecidos.any?
  end
end
