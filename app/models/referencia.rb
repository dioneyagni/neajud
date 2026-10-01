# A grouping of artes inside one molde (Etapa 1.1, 5/5): "19" and "20" of
# 001-TNS, "Fuel" and "Elite" of 002-JGG. Each molde has its own — the "20" of
# 001-TNS and the "20" of 002-TNS are different records. Not catalog, not
# versioned. Names are unique per molde ignoring case and accents.
#
# Usage: Referencia.do_molde!(molde, "19") # finds "19" or creates it
class Referencia < ApplicationRecord
  include GeraUuid

  belongs_to :molde
  has_many :arquivos, dependent: :nullify

  validates :nome, presence: true
  validate :nome_unico_no_molde

  def self.do_molde!(molde, nome)
    molde.referencias.find { |r| TextoComparavel.iguais?(r.nome, nome) } || molde.referencias.create!(nome: nome.to_s.squish)
  end

  private

  def nome_unico_no_molde
    outras = Referencia.where(molde_id: molde_id).where.not(id: id)
    return unless outras.any? { |r| TextoComparavel.iguais?(r.nome, nome) }

    errors.add(:nome, "#{nome.inspect} already exists in this molde (names ignore case and accents)")
  end
end
