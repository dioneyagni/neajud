# A molde's price per pair for a band of its produto's grade (Etapa 2.4,
# decided 09/10/2026: calçado is charged per pair; the molde already belongs
# to one client, so its price is the price agreed with that client). Bands
# may cover numbers outside the molde's stretch ("+ 23" in a pedido) and
# never overlap. A pedido confirmed keeps the price it had then
# (ItemPedidoGrade#preco_par); removing a band is physical on purpose, like
# removing a part from the molde.
#
# Usage: molde.faixas_de_preco.create!(tamanho_inicial: "23", tamanho_final: "30", preco_par: "9.50")
#        molde.preco_do_par("27") # => 9.5
class FaixaDePreco < ApplicationRecord
  include GeraUuid

  self.table_name = "faixas_de_preco"

  belongs_to :molde

  validates :preco_par, numericality: { greater_than_or_equal_to: 0 }
  validate :trecho_da_grade
  validate :sem_sobrepor

  # The band's numbers; empty when its ends aren't a stretch of the grade.
  # Usage: faixa.numeros # => ["23", "24", …, "30"]
  def numeros
    molde.modelo&.produto&.trecho_da_grade(tamanho_inicial, tamanho_final) || []
  end

  # "23–30", or "27" for a band of one number.
  def rotulo
    tamanho_inicial == tamanho_final ? tamanho_inicial.to_s : "#{tamanho_inicial}–#{tamanho_final}"
  end

  private

  def trecho_da_grade
    return if molde.nil? || numeros.any?

    grade = molde.modelo&.produto&.grade.to_a
    return errors.add(:base, "#{molde.nome} has no grade: its modelo's produto lists no sizes") if grade.empty?

    errors.add(:tamanho_final, "#{tamanho_inicial.inspect}–#{tamanho_final.inspect} is not a stretch of #{grade.first}–#{grade.last} (both ends in the grade, first ≤ last)")
  end

  def sem_sobrepor
    return if molde.nil? || numeros.empty?

    outra = molde.faixas_de_preco.where.not(id: id).find { |faixa| faixa.numeros.intersect?(numeros) }
    errors.add(:base, "#{rotulo} overlaps the band #{outra.rotulo} of #{molde.nome}: each number has one price") if outra
  end
end
