# A user's access to the empresa: one função (shared by many workers) plus
# optional acessos_extras ({ "niveis" => { área => level }, "acoes" => [...] })
# that can only raise it (Etapa 0.5, 2/4; extras are edited from 3/4).
class Vinculo < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  belongs_to :user
  belongs_to :empresa
  belongs_to :funcao
  # Etapa 2.8: a cliente final's vínculo is tied to one Client (blank = team).
  belongs_to :client, optional: true
  recusa_excluido :funcao, :client

  validates :user_id, uniqueness: { scope: :empresa_id }
  validate :acessos_extras_validos
  validate :tipo_da_funcao

  # Usage: vinculo.autorizacao.pode?(:pedidos, :ver)
  def autorizacao
    Autorizacao.new(funcao, acessos_extras)
  end

  private

  # A client's vínculo takes only funções para clientes, and the team's never
  # one (Etapa 2.8, 2/5); its extras stay within the same limits.
  def tipo_da_funcao
    return unless funcao

    errors.add(:funcao, "\"#{funcao.nome}\" is a team função; a client's access needs a função para clientes") if client_id && !funcao.para_cliente?
    errors.add(:funcao, "\"#{funcao.nome}\" is for clientes finais; choose a team função") if !client_id && funcao.para_cliente?
    Autorizacao.erros_para_cliente(acessos_extras.to_h.fetch("niveis", {}), acessos_extras.to_h["acoes"]).each { |erro| errors.add(:acessos_extras, erro) } if client_id
  end

  def acessos_extras_validos
    extras = acessos_extras.to_h.stringify_keys
    Autorizacao.erros_da_grade(extras.fetch("niveis", {}), extras.fetch("acoes", [])).each { |erro| errors.add(:acessos_extras, erro) }
  end
end
