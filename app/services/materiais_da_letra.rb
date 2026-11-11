# What a dublagem line (item × letra, Dublagem 5b1c1) takes, and the lines a
# missing material holds (Dublagem 5b1c3, decided 11/11/2026, Q1a): a letra
# takes the materials of the layers it joins itself — never an earlier
# letra's, which it already waits for — and its ligante, the item's meters
# of each, the layer's owner the construção's client when it is his
# (ComponentesDaDublagem's rule). The confirmation took them from the stock;
# while one is missing for the pedido (AguardandoMaterial) the letra is
# held, and so is every letra waiting for a held one.
#
# Usage: MateriaisDaLetra.call(linha) # => [#<Parte materia_prima=Espuma client=nil esperado=10.0>, #<Parte materia_prima=Helanca …>]
#        MateriaisDaLetra.presas(linhas, aguardando.do_pedido(pedido)) # => { "<item>/3" => [Espuma], "<item>/4" => [Espuma] }
class MateriaisDaLetra
  def self.call(linha)
    dublagem = linha.dublagem
    cliente = linha.item.construcao.client
    partes = dublagem.lados.reject(&:dublagem?).map { |folha| [ folha.camada.materia_prima, (cliente if folha.camada.do_cliente) ] }
    partes << [ dublagem.juncao.ligante, nil ] if dublagem.juncao.ligante
    partes.uniq.map { |material, client| MateriaisDasLinhas::Parte.new(materia_prima: material, client: client, esperado: linha.esperado.to_f) }
  end

  # The open dublagem lines a falta holds, by chave, with the materials
  # holding each: a line taking a missing material (by material and owner),
  # then the ones waiting for a held line, until none is added.
  def self.presas(linhas, faltas)
    faltando = faltas.to_set { |falta| [ falta.materia_prima.id, falta.client&.id ] }
    presas = linhas.each_with_object({}) do |linha, mapa|
      materiais = call(linha).select { |parte| faltando.include?([ parte.materia_prima.id, parte.client&.id ]) }.map(&:materia_prima)
      mapa[linha.chave] = materiais if materiais.any?
    end
    propagar(linhas, presas)
  end

  def self.propagar(linhas, presas)
    loop do
      novas = linhas.reject { |linha| presas.key?(linha.chave) }.filter_map do |linha|
        esperadas = Array(linha.espera).filter_map { |espera| presas[espera.chave] }
        [ linha.chave, esperadas.flatten.uniq ] if esperadas.any?
      end
      return presas if novas.empty?

      presas.merge!(novas.to_h)
    end
  end
  private_class_method :propagar
end
