# What changed between two readings of a ligação (LigacaoDublagem#resumo),
# as the line its histórico keeps (rede editável 2/2a, decided 10/11/2026,
# Q3a): short, field by field, empty when nothing changed.
#
# Usage: MudancasDaLigacao.new(antes, depois).texto
#        # => "dubla antes → depois; tirou o ligante Filme 25 µm; Tecido molha: Filme PU → os de cima; a confirmar: ligantes → nenhum"
class MudancasDaLigacao
  def initialize(antes, depois)
    @antes = antes
    @depois = depois
  end

  def texto
    [ troca("lado", @antes["lado"], @depois["lado"]), troca("dubla", @antes["dubla"], @depois["dubla"]),
      *ligantes, *situacoes, a_confirmar ].compact.join("; ")
  end

  private

  def troca(campo, antes, depois)
    "#{campo} #{antes} → #{depois}" unless antes == depois
  end

  def ligantes
    (@antes["ligantes"] - @depois["ligantes"]).map { |ligante| "tirou o ligante #{ligante}" } +
      (@depois["ligantes"] - @antes["ligantes"]).map { |ligante| "pôs o ligante #{ligante}" }
  end

  # A situação that lists no ligantes keeps the usual ones: "os de cima".
  def situacoes
    (@antes["situacoes"].keys | @depois["situacoes"].keys).filter_map do |situacao|
      antes, depois = [ @antes, @depois ].map { |resumo| resumo["situacoes"][situacao]&.join(" ou ") || "os de cima" }
      "#{situacao}: #{antes} → #{depois}" unless antes == depois
    end
  end

  def a_confirmar
    antes, depois = [ @antes, @depois ].map { |resumo| resumo["a_confirmar"].join(", ").presence || "nenhum" }
    "a confirmar: #{antes} → #{depois}" unless antes == depois
  end
end
