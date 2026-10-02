# A corte's grade type and the individual sizes each of its tamanhos serves
# (Etapa 1.2, 1/3; docs/plano.md "Tamanhos e grade"):
#   par    — pairs ending in an even number: 23-24, 25-26 …
#   impar  — pairs ending in an odd number:  34-35, 36-37 …
#   pmg    — labels (PP, P, M, G…), each with the numbers it serves
#   furada — irregular ranges read from the name: 20-21, 24-25-26, 30
# Sizes are strings ("29", "P"), the same as a molde's grade.
#
# Usage: GradeDoCorte.deduzir(%w[24 26 28])
#   # => { tipo: "par", tamanhos: [{ nome: "23-24", numeros: %w[23 24] }, …] }
#        GradeDoCorte.ler("impar", rotulo: nil, tamanhos: "35") # => { nome: "34-35", numeros: %w[34 35] }
class GradeDoCorte
  TIPOS = { "par" => "Par", "impar" => "Ímpar", "pmg" => "P/M/G", "furada" => "Furada" }.freeze
  ROTULOS_PMG = %w[PP P M G GG XG XGG EG].freeze
  SO_NUMEROS = /\A\d+(\s*[-,]\s*\d+)*\z/

  class Invalido < StandardError; end

  # The type the detected names point to, with each tamanho filled; nil when
  # nothing can be deduced ("Size 1") — the person picks the type then.
  def self.deduzir(nomes)
    nomes = nomes.map { |n| n.to_s.strip }
    return pmg(nomes) if nomes.any? && nomes.all? { |n| ROTULOS_PMG.include?(n.upcase) }
    return nil if nomes.empty? || !nomes.all? { |n| n.match?(SO_NUMEROS) }

    listas = nomes.map { |n| numeros_do_texto(n) }
    pares_por_ultimo(listas) || pares_escritos(listas) || furada(nomes, listas)
  end

  # What the person typed for one tamanho, checked against the type.
  # Raises Invalido with the offending value and the expected shape.
  def self.ler(tipo, rotulo:, tamanhos:)
    case tipo
    when "par", "impar" then ler_par(tipo, tamanhos)
    when "furada" then ler_furada(rotulo, tamanhos)
    when "pmg" then ler_pmg(rotulo, tamanhos)
    else raise Invalido, "Grade type #{tipo.inspect} is not one of #{TIPOS.keys.join(", ")}"
    end
  end

  def self.numeros_do_texto(texto)
    texto.to_s.scan(/\d+/).map { |n| n.to_i.to_s }
  end

  def self.pmg(nomes)
    { tipo: "pmg", tamanhos: nomes.map { |n| { nome: n.upcase, numeros: [] } } }
  end

  # "24, 26 … 34": one number per size, every other one — the last of a pair.
  def self.pares_por_ultimo(listas)
    return nil unless listas.all? { |l| l.size == 1 }

    ultimos = listas.flatten.map(&:to_i)
    return nil unless ultimos.size > 1 && ultimos.each_cons(2).all? { |a, b| b == a + 2 }

    { tipo: ultimos.first.even? ? "par" : "impar", tamanhos: ultimos.map { |n| par(n - 1, n) } }
  end

  # "34-35, 36-37 …": written pairs, all ending in the same parity.
  def self.pares_escritos(listas)
    pares = listas.map { |l| l.map(&:to_i) }
    return nil unless pares.all? { |l| l.size == 2 && l[1] == l[0] + 1 }
    # size, not one?: [false].one? is false (one? counts truthy values).
    return nil unless pares.map { |_, b| b.even? }.uniq.size == 1

    { tipo: pares.first[1].even? ? "par" : "impar", tamanhos: pares.map { |a, b| par(a, b) } }
  end

  def self.furada(nomes, listas)
    { tipo: "furada", tamanhos: nomes.zip(listas).map { |nome, numeros| { nome: nome, numeros: numeros } } }
  end

  def self.par(a, b)
    { nome: "#{a}-#{b}", numeros: [ a.to_s, b.to_s ] }
  end

  def self.ler_par(tipo, texto)
    numeros = numeros_do_texto(texto).map(&:to_i)
    numeros = [ numeros.first - 1, numeros.first ] if numeros.one?
    a, b = numeros
    paridade_ok = b && (tipo == "par" ? b.even? : b.odd?)
    unless numeros.size == 2 && b == a + 1 && paridade_ok
      raise Invalido, "#{texto.inspect} isn't a #{TIPOS[tipo]} pair; expected two consecutive sizes ending in an #{tipo == "par" ? "even" : "odd"} number, e.g. #{tipo == "par" ? "29-30" : "30-31"}"
    end

    par(a, b)
  end

  def self.ler_furada(rotulo, texto)
    numeros = numeros_do_texto(texto)
    unless texto.to_s.strip.match?(SO_NUMEROS) && numeros.uniq == numeros
      raise Invalido, "#{texto.inspect} isn't a list of sizes; expected numbers separated by hyphens, e.g. 24-25-26"
    end

    { nome: rotulo.to_s.strip.presence || numeros.join("-"), numeros: numeros }
  end

  def self.ler_pmg(rotulo, texto)
    raise Invalido, "A P/M/G size needs its label (PP, P, M, G…); got #{rotulo.inspect}" if rotulo.to_s.strip.empty?

    numeros = numeros_do_texto(texto)
    { nome: rotulo.to_s.strip.upcase, numeros: numeros }
  end

  private_class_method :pmg, :pares_por_ultimo, :pares_escritos, :furada, :par, :ler_par, :ler_furada, :ler_pmg
end
