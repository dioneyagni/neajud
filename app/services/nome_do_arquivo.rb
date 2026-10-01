# Reads an arte's Referência and Nome from its file name, the way the team
# names files today (Etapa 1.1, 5/5): "19-BLUEY PTO-LINGUA" → referência
# "19", nome "BLUEY PTO". A leading number is the referência; part names
# (any of the company's peças) and sizes ("29_30", "29-30", "30") are left
# out of the name.
#
# Usage: NomeDoArquivo.ler("20-base-LATERAL-29_30", partes: ["Lateral", "Língua"])
#   # => { referencia: "20", nome: "base" }
class NomeDoArquivo
  SEPARADORES = /[-_]/
  NUMERO = /\A\d+\z/

  def self.ler(nome_do_arquivo, partes:)
    new(nome_do_arquivo, partes).ler
  end

  def initialize(nome_do_arquivo, partes)
    @pedacos = File.basename(nome_do_arquivo.to_s, ".*").split(SEPARADORES).map(&:squish).reject(&:empty?)
    @partes = partes.map { |p| TextoComparavel.chave(p) }
  end

  def ler
    referencia = @pedacos.shift if @pedacos.first&.match?(NUMERO)
    nome = @pedacos.reject { |p| p.match?(NUMERO) || @partes.include?(TextoComparavel.chave(p)) }.join(" ")
    { referencia: referencia, nome: nome.presence }
  end
end
