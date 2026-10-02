# Does a corte cover the grade of each molde it serves? (Etapa 1.2, 1/3) For
# every number of the molde's stretch (Molde#grade) exactly one of the
# corte's tamanhos should serve it: a missing number has no DXF to cut, a
# repeated one leaves it ambiguous. Numbers outside the stretch (the 23 of
# a 23-24 pair) don't matter.
#
# Only a warning (decided 01/10/2026): the molde may get its stretch later,
# and a corte serving several moldes may be right for some and not others.
# Checked only once the corte has a grade type (its numbers are known).
#
# Usage: CoberturaDaGrade.avisos(corte).map(&:descricao)
#   # => ["001-TNS Base: falta 24; o 26 está em dois tamanhos"]
class CoberturaDaGrade
  Aviso = Struct.new(:molde, :faltando, :repetidos, keyword_init: true) do
    def descricao
      partes = []
      partes << "#{faltando.one? ? "falta" : "faltam"} #{faltando.join(", ")}" if faltando.any?
      partes << "#{repetidos.join(", ")} #{repetidos.one? ? "está" : "estão"} em dois tamanhos" if repetidos.any?
      "#{molde.nome}: #{partes.join("; ")}"
    end
  end

  # The moldes the corte is linked to (the corte page).
  def self.avisos(corte)
    corte.moldes.ativos.filter_map { |molde| aviso_do_molde(corte, molde) }
  end

  # One molde, linked or reached by the same-modelo fallback
  # (Arquivo.cortes_do_molde — the molde page).
  # Usage: CoberturaDaGrade.aviso_do_molde(corte, molde) # => Aviso or nil
  def self.aviso_do_molde(corte, molde)
    return nil unless corte.corte? && corte.tipo_grade.present?

    aviso(molde, corte.tamanhos.flat_map { |t| t.numeros.presence || [ t.nome ] })
  end

  def self.aviso(molde, atendidos)
    grade = molde.grade
    return nil if grade.empty?

    faltando = grade - atendidos
    repetidos = grade.select { |numero| atendidos.count(numero) > 1 }
    Aviso.new(molde: molde, faltando: faltando, repetidos: repetidos) if faltando.any? || repetidos.any?
  end
  private_class_method :aviso
end
