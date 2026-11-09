# A ligante a ligação allows (rede editável 1/2, 09/11/2026): a group, with
# the micras it may have — a list, a minimum or any (both nil). Without a
# situação it is a usual one; with one, it replaces the usual ones in that
# situação (decision 3). Addressed by position inside its ligação, so no uuid.
class LiganteDaLigacao < ApplicationRecord
  self.table_name = "ligantes_da_ligacao"

  belongs_to :ligacao_dublagem, inverse_of: :ligantes
  belongs_to :situacao_dublagem, optional: true, inverse_of: :ligantes
  belongs_to :grupo_material

  validates :posicao, numericality: { only_integer: true, greater_than: 0 }
  validates :micras_minimo, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :micras_inteiras
  validate :lista_ou_minimo

  after_commit { RedeDeDublagens.esquecer }

  # Usage: ligante.para_rede.descricao # => "Filme 25 ou 35 µm"
  def para_rede = RedeDeDublagens::Ligante.new(grupo: grupo_material.nome, micras: micras.presence, minimo: micras_minimo)

  private

  def micras_inteiras
    return if micras.nil? || (micras.is_a?(Array) && micras.any? && micras.all? { |valor| valor.is_a?(Integer) && valor.positive? })

    errors.add(:micras, "#{micras.inspect} is not a list of micras; expected positive integers, e.g. [25, 35]")
  end

  def lista_ou_minimo
    errors.add(:base, "micras #{micras.inspect} and minimum #{micras_minimo} together; expected a list or a minimum") if micras.present? && micras_minimo
  end
end
