# The "todas as cores" chart (Etapa 2.5b, the layout in docs/cor-lisa/): a
# grid of tiles that fills as colors come in — a column per 30° of hue (the
# grays first), a row per band of lightness, lightest on top. Each cell keeps
# its colors, newest first; an empty cell is drawn dark gray.
#
# Usage: CartelaDeCores.call(cores).linhas.first.first # => #<struct cores=[…], …>
class CartelaDeCores
  COLUNAS = 13 # grays + 12 hues of 30°
  FAIXAS_DE_CLARIDADE = [ 80, 60, 40, 20, 0 ].freeze
  Celula = Struct.new(:coluna, :faixa, :cores)
  Cartela = Struct.new(:linhas)

  # cores: [[arte, versao]] of measured cores lisas.
  def self.call(cores)
    linhas = FAIXAS_DE_CLARIDADE.map { |faixa| Array.new(COLUNAS) { |coluna| Celula.new(coluna, faixa, []) } }
    cores.sort_by { |arte, _| -arte.id }.each do |arte, versao|
      l, c, h = FamiliasDeCor.lch(versao.lab)
      linha = FAIXAS_DE_CLARIDADE.index { |faixa| l >= faixa } || FAIXAS_DE_CLARIDADE.size - 1
      linhas[linha][coluna(c, h)].cores << [ arte, versao ]
    end
    Cartela.new(linhas)
  end

  # Usage: CartelaDeCores.coluna(80.9, 47.7) # => 2
  def self.coluna(croma, matiz)
    return 0 if croma < FamiliasDeCor.tabela.dig("neutras", "croma_abaixo_de")

    1 + (matiz / 30).floor % 12
  end
end
