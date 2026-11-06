# Brazil's national holidays of a year, computed here — no outside service
# (Painel 2/4a, decided 05/11/2026, Q9a: suggested, the dono confirms the
# ones the factory stops on). The movable ones follow Easter (the Gregorian
# computus). Carnaval and Corpus Christi are "ponto facultativo" nationally:
# suggested too, marked so the dono knows.
#
# Usage: FeriadosNacionais.do_ano(2026).map { |f| [ f.data.to_s, f.nome ] }
#   # => [["2026-01-01", "Confraternização Universal"], ["2026-02-16", "Carnaval"], …]
class FeriadosNacionais
  Feriado = Struct.new(:data, :nome, :facultativo, keyword_init: true)

  FIXOS = {
    [ 1, 1 ] => "Confraternização Universal", [ 4, 21 ] => "Tiradentes", [ 5, 1 ] => "Dia do Trabalho",
    [ 9, 7 ] => "Independência do Brasil", [ 10, 12 ] => "Nossa Senhora Aparecida", [ 11, 2 ] => "Finados",
    [ 11, 15 ] => "Proclamação da República",
    # Lei 14.759/2023: national since 2024.
    [ 11, 20 ] => "Dia Nacional de Zumbi e da Consciência Negra", [ 12, 25 ] => "Natal"
  }.freeze
  # Days from Easter Sunday: [offset, name, ponto facultativo?]
  MOVEIS = [ [ -48, "Carnaval", true ], [ -47, "Carnaval", true ], [ -2, "Sexta-feira Santa", false ], [ 60, "Corpus Christi", true ] ].freeze

  def self.do_ano(ano)
    fixos = FIXOS.map { |(mes, dia), nome| Feriado.new(data: Date.new(ano, mes, dia), nome: nome, facultativo: false) }
    moveis = MOVEIS.map { |dias, nome, facultativo| Feriado.new(data: pascoa(ano) + dias, nome: nome, facultativo: facultativo) }
    (fixos + moveis).sort_by(&:data)
  end

  # Easter Sunday (the anonymous Gregorian algorithm, Meeus/Jones/Butcher).
  # Usage: FeriadosNacionais.pascoa(2026) # => Sun, 05 Apr 2026
  def self.pascoa(ano)
    a, b, c = ano % 19, ano / 100, ano % 100
    f = (b + 8) / 25
    g = (b - f + 1) / 3
    h = ((19 * a) + b - (b / 4) - g + 15) % 30
    l = (32 + (2 * (b % 4)) + (2 * (c / 4)) - h - (c % 4)) % 7
    m = (a + (11 * h) + (22 * l)) / 451
    n = h + l - (7 * m) + 114
    Date.new(ano, n / 31, (n % 31) + 1)
  end
end
