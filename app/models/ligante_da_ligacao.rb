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

  # The micras as typed on the ligação's page (rede editável 2/2a): blank is
  # any, "25, 35" (or "25 ou 35") a list, "35 ou mais" (or "35+") a minimum;
  # nil for anything else.
  # Usage: LiganteDaLigacao.micras_digitadas("35 ou mais") # => { micras: nil, micras_minimo: 35 }
  def self.micras_digitadas(texto)
    texto = texto.to_s.strip
    return { micras: nil, micras_minimo: nil } if texto.empty?
    return { micras: nil, micras_minimo: Regexp.last_match(1).to_i } if texto =~ /\A(\d+)\s*(?:\+|ou mais)\z/

    valores = texto.split(/\s*(?:,|\bou\b)\s*/, -1)
    { micras: valores.map(&:to_i), micras_minimo: nil } if valores.all? { |valor| valor.match?(/\A[1-9]\d*\z/) }
  end

  # What was typed, kept so a refused save shows it again (SalvarLigacao).
  attr_writer :texto_das_micras

  # The other way, for the form. Usage: ligante.micras_no_campo # => "25, 35", "35 ou mais", ""
  def micras_no_campo
    return @texto_das_micras.to_s if @texto_das_micras
    return "#{micras_minimo} ou mais" if micras_minimo

    Array(micras).join(", ")
  end

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
