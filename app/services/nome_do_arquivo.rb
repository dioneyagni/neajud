# Reads an arte's Referência, Nome and size from its file name, the way the
# team names files today (Etapa 1.1, 5/5; size since Etapa 1.2, 2/3):
# "19-BLUEY PTO-LINGUA" → referência "19", nome "BLUEY PTO". A leading
# number is the referência; part names (any of the company's peças), sizes
# ("29_30", "29-30", "30", "P") and measures ("1,9 X 1,3") are left out of
# the name. The numbers after the referência are the size ("29-30"), else a
# P/M/G label.
#
# Usage: NomeDoArquivo.ler("20-base-LATERAL-29_30", partes: ["Lateral", "Língua"])
#   # => { referencia: "20", nome: "base", tamanho: "29-30" }
class NomeDoArquivo
  SEPARADORES = /[-_]/
  NUMERO = /\A\d+\z/
  MEDIDA = /\d+(?:[,.]\d+)?\s*[xX]\s*\d+(?:[,.]\d+)?/

  def self.ler(nome_do_arquivo, partes:)
    new(nome_do_arquivo, partes).ler
  end

  def initialize(nome_do_arquivo, partes)
    @pedacos = File.basename(nome_do_arquivo.to_s, ".*").split(SEPARADORES).map { |p| p.gsub(MEDIDA, "").squish }.reject(&:empty?)
    @partes = partes.map { |p| TextoComparavel.chave(p) }
  end

  def ler
    referencia = @pedacos.shift if @pedacos.first&.match?(NUMERO)
    nome = @pedacos.reject { |p| p.match?(NUMERO) || rotulo_pmg?(p) || @partes.include?(TextoComparavel.chave(p)) }.join(" ")
    { referencia: referencia, nome: nome.presence, tamanho: tamanho }
  end

  private

  def tamanho
    numeros = @pedacos.grep(NUMERO)
    return numeros.join("-") if numeros.any?

    @pedacos.find { |p| rotulo_pmg?(p) }
  end

  # Upper case only: a lower "m" or "g" is more likely a word than a size.
  def rotulo_pmg?(pedaco)
    GradeDoCorte::ROTULOS_PMG.include?(pedaco)
  end
end
