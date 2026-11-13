# What a person sees of the pedidos waiting for material (Etapa 2.3d2,
# decided 19/10/2026): the team every material and meter; a cliente final
# that his pedido waits, and the meters only of his own fabric — never the
# empresa's paper or stock (Visibilidade).
# Dublagem 5a: a dublado missing is "dublagem" — an ordem de dublagem makes
# it —, and a cliente final sees only that word (never the layers).
module AguardandoMaterialHelper
  # Computed once per request; a controller that filters by it sets the same
  # instance variable.
  def aguardando_material
    @aguardando_material ||= AguardandoMaterial.call
  end

  # Usage: aguardando_do_pedido(pedido) # => "Oxford-Preto-1.50 do cliente · faltam 12,5 m; Papel-Branco-1.60 da empresa · faltam 3 m"
  #        (a cliente final with none of his own fabric missing: "material")
  #        (Dublagem 5a: "dublagem de Oxford Branco / Lona…-1.40 m · faltam 4 m"; a cliente final: "dublagem")
  def aguardando_do_pedido(pedido)
    faltas = aguardando_material.do_pedido(pedido)
    return if faltas.empty?

    dublagens, materiais = faltas.partition { |falta| falta.materia_prima.dublado? }
    [ (materiais_que_faltam(materiais) if materiais.any?), (dublagens_que_faltam(dublagens) if dublagens.any?) ].compact.join("; ")
  end

  # The meters of a tecido line's dublado the pedido still waits for
  # (Dublagem 5a), on the production page; nil when none.
  # Usage: aguardando_dublagem_da_linha(pedido, linha) # => 4.0
  def aguardando_dublagem_da_linha(pedido, linha)
    return unless linha.materia_prima&.dublado?

    faltas = aguardando_material.do_pedido(pedido).select { |falta| falta.materia_prima == linha.materia_prima }
    faltas.sum(&:metros) if faltas.any?
  end

  # What a dublagem line's letra waits for (Dublagem 5b1c3, Q2a): a
  # material it takes missing for the pedido; nil when none. A cliente final
  # sees the meters only of his own fabric (materiais_que_faltam).
  # Usage: aguardando_da_letra(pedido, linha) # => "aguarda Espuma TC4 Branco-1.40 m da empresa · faltam 10 m"
  def aguardando_da_letra(pedido, linha)
    partes = MateriaisDaLetra.call(linha).to_set { |parte| [ parte.materia_prima, parte.client ] }
    faltas = aguardando_material.do_pedido(pedido).select { |falta| partes.include?([ falta.materia_prima, falta.client ]) }
    "aguarda #{materiais_que_faltam(faltas)}" if faltas.any?
  end

  # The pedidos list's badge (Dublagem 5a).
  # Usage: rotulo_do_aguardando(pedido) # => "aguardando dublagem", "aguardando material" or nil
  def rotulo_do_aguardando(pedido)
    faltas = aguardando_material.do_pedido(pedido)
    return if faltas.empty?

    dublagens, materiais = faltas.partition { |falta| falta.materia_prima.dublado? }
    return "aguardando dublagem" if materiais.empty?

    dublagens.empty? ? "aguardando material" : "aguardando material e dublagem"
  end

  # Usage: aguardando_do_material(oxford) # => "Aguardando: 2 pedidos · faltam 20 m"
  def aguardando_do_material(material)
    faltas = faltas_visiveis(aguardando_material.do_material(material))
    return if faltas.empty?

    pedidos = faltas.map(&:pedido_id).uniq.size
    "Aguardando: #{pedidos} #{pedidos == 1 ? "pedido" : "pedidos"} · faltam #{quantidade_do_material(faltas.sum(&:metros), material)}"
  end

  private

  def materiais_que_faltam(faltas)
    proprias = faltas_visiveis(faltas)
    return "material" if proprias.empty?

    proprias.map { |falta| "#{falta.materia_prima.nome_completo} #{falta.client ? "do cliente" : "da empresa"} · faltam #{quantidade_do_material(falta.metros, falta.materia_prima)}" }.join("; ")
  end

  def dublagens_que_faltam(faltas)
    return "dublagem" if cliente_final?

    faltas.map { |falta| "dublagem de #{falta.materia_prima.nome_completo} · faltam #{metros(falta.metros)}" }.join("; ")
  end

  def faltas_visiveis(faltas)
    return faltas unless cliente_final?

    faltas.select { |falta| falta.client && falta.client == Current.user.cliente }
  end
end
