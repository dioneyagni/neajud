# What a person sees of the pedidos waiting for material (Etapa 2.3d2,
# decided 19/10/2026): the team every material and meter; a cliente final
# that his pedido waits, and the meters only of his own fabric — never the
# empresa's paper or stock (Visibilidade).
module AguardandoMaterialHelper
  # Computed once per request; a controller that filters by it sets the same
  # instance variable.
  def aguardando_material
    @aguardando_material ||= AguardandoMaterial.call
  end

  # Usage: aguardando_do_pedido(pedido) # => "Oxford-Preto-1.50 do cliente · faltam 12,5 m; Papel-Branco-1.60 da empresa · faltam 3 m"
  #        (a cliente final with none of his own fabric missing: "material")
  def aguardando_do_pedido(pedido)
    faltas = aguardando_material.do_pedido(pedido)
    return if faltas.empty?

    proprias = faltas_visiveis(faltas)
    return "material" if proprias.empty?

    proprias.map { |falta| "#{falta.materia_prima.nome_completo} #{falta.client ? "do cliente" : "da empresa"} · faltam #{metros(falta.metros)}" }.join("; ")
  end

  # Usage: aguardando_do_material(oxford) # => "Aguardando: 2 pedidos · faltam 20 m"
  def aguardando_do_material(material)
    faltas = faltas_visiveis(aguardando_material.do_material(material))
    return if faltas.empty?

    pedidos = faltas.map(&:pedido_id).uniq.size
    "Aguardando: #{pedidos} #{pedidos == 1 ? "pedido" : "pedidos"} · faltam #{metros(faltas.sum(&:metros))}"
  end

  private

  def faltas_visiveis(faltas)
    return faltas unless cliente_final?

    faltas.select { |falta| falta.client && falta.client == Current.user.cliente }
  end
end
