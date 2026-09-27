# A user's access to the empresa: one função (shared by many workers) plus
# optional acessos_extras ({ "niveis" => { área => level }, "acoes" => [...] })
# that can only raise it (Etapa 0.5, 2/4; extras are edited from 3/4).
class Vinculo < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  belongs_to :user
  belongs_to :empresa
  belongs_to :funcao
  recusa_excluido :funcao

  validates :user_id, uniqueness: { scope: :empresa_id }
  validate :acessos_extras_validos

  # Usage: vinculo.autorizacao.pode?(:pedidos, :ver)
  def autorizacao
    Autorizacao.new(funcao, acessos_extras)
  end

  private

  def acessos_extras_validos
    extras = acessos_extras.to_h.stringify_keys
    Autorizacao.erros_da_grade(extras.fetch("niveis", {}), extras.fetch("acoes", [])).each { |erro| errors.add(:acessos_extras, erro) }
  end
end
