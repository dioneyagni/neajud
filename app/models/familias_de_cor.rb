# The cor lisa's family from its measured color (Etapa 2.5b, decided
# 12/10/2026): the fixed table in config/familias_de_cor.yml, read as LCh —
# grays by chroma first, then the first band that holds the hue (and the
# lightness or chroma it asks). Raises on a table that names no family for
# a color, so a hole in the bands is found by the specs, not by a user.
#
# Usage: FamiliasDeCor.classificar([54.3, 64.7, 55.3]) # => "Laranja"
module FamiliasDeCor
  ARQUIVO = Rails.root.join("config/familias_de_cor.yml")

  module_function

  def classificar(lab)
    l, c, h = lch(lab)
    regras = c < tabela.dig("neutras", "croma_abaixo_de") ? tabela.dig("neutras", "familias") : tabela["familias"]
    regra = regras.find { |r| atende?(r, l, c, h) }
    raise ArgumentError, "no color family for L*=#{l.round(1)} C*=#{c.round(1)} h=#{h.round(1)}; expected #{ARQUIVO} to cover it" unless regra

    regra["nome"]
  end

  # Usage: FamiliasDeCor.limite(:parecida) # => 3.0
  def limite(nome)
    tabela.fetch("parecida").fetch(nome.to_s)
  end

  # Usage: FamiliasDeCor.lch([46.2, 1.5, -46.3]) # => [46.2, 46.3, 271.8]
  def lch(lab)
    l, a, b = lab.map(&:to_f)
    [ l, Math.hypot(a, b), Math.atan2(b, a) * 180 / Math::PI % 360 ]
  end

  def atende?(regra, l, c, h)
    return false if regra["de"] && !no_arco?(h, regra["de"], regra["ate"])
    return false if regra["claridade_abaixo_de"] && l >= regra["claridade_abaixo_de"]
    return false if regra["claridade_a_partir_de"] && l < regra["claridade_a_partir_de"]

    !(regra["croma_abaixo_de"] && c >= regra["croma_abaixo_de"])
  end

  # A band may wrap past 360 (de: 330, ate: 15).
  def no_arco?(h, de, ate)
    de <= ate ? h >= de && h < ate : h >= de || h < ate
  end

  def tabela
    @tabela ||= YAML.load_file(ARQUIVO)
  end
end
