# Names compared the way people read them (Etapa 1.1, 5/5): "Bluey Azul",
# "bluey azul" and "BLUEY  AZUL" are one name; "Lingua" and "Língua", "Cabeca"
# and "Cabeça" too.
# Usage: TextoComparavel.chave("  Língua ") # => "lingua"
module TextoComparavel
  def self.chave(texto)
    I18n.transliterate(texto.to_s).downcase.squish
  end

  def self.iguais?(a, b)
    chave(a) == chave(b)
  end
end
