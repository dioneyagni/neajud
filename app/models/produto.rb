# A broad product (Calçado, Camisa, Banner) from the official Neajud list
# (config/catalogo_oficial.yml, loaded by CatalogoOficial — Etapa 1.1, 3/5).
# Its grade is the ordered list of individual sizes; a molde uses a stretch of
# it. The company never edits it: a product that leaves the list goes to the
# trash, so moldes that use it keep their reference.
#
# Usage: Produto.find_by!(nome: "Calçado").grade # => ["18", "19", …, "46"]
class Produto < ApplicationRecord
  include GeraUuid
  include Excluivel

  has_many :modelos, dependent: :restrict_with_error

  validates :nome, presence: true, uniqueness: { case_sensitive: false }
  validate :grade_e_lista_de_textos

  # A molde's stretch of the grade, inclusive; nil when either end isn't in it.
  # Usage: produto.trecho_da_grade("33", "36") # => ["33", "34", "35", "36"]
  def trecho_da_grade(inicial, final)
    de = grade.index(inicial)
    ate = grade.index(final)
    return nil unless de && ate && de <= ate

    grade[de..ate]
  end

  private

  def grade_e_lista_de_textos
    return if grade.is_a?(Array) && grade.all? { |t| t.is_a?(String) && t.present? }

    errors.add(:grade, "must be an ordered list of size labels (e.g. [\"18\", \"19\"] or [\"P\", \"M\"]); got #{grade.inspect}")
  end
end
