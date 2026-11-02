# Materials of the dublagem network for the construção's specs (Dublagem
# 3/5): each group with the roles config/dublagens.yml expects, and a
# construção built from layers.
# Usage: oxford = material_de_dublagem("Oxford", preco: 20)
#        filme = material_de_dublagem("Filme", tipo: "filme", micras: 35, preco: 3)
#        construcao = montar_construcao([ oxford, "trama" ], [ lona, filme ], preco_final: 46)
module Construcoes
  PAPEIS = { "Oxford" => %i[superficie base], "Telinha" => %i[superficie], "Lona" => %i[base], "EVA" => %i[base],
             "Espuma" => %i[base], "Helanca" => %i[base], "Filme" => [], "Filme PU" => [] }.freeze

  def material_de_dublagem(grupo, tipo: "tecido", cor: "Branco", largura: "1.40 m", micras: nil, densidade: nil, preco: nil)
    papeis = PAPEIS.fetch(grupo)
    grupo_material = GrupoMaterial.create_with(superficie: papeis.include?(:superficie), base: papeis.include?(:base), atributos: {})
                                  .find_or_create_by!(nome: grupo)
    MateriaPrima.create!(grupo_material: grupo_material, cor_material: CorMaterial.find_or_create_by!(nome: cor), tipo: tipo,
                         largura: largura, micras: micras, densidade: densidade, preco_metro: preco)
  end

  # Each layer: [material, lado] for the superfície, [material, ligante] or
  # [material, ligante, do_cliente: true] for a base.
  def montar_construcao(superficie, *bases, **atributos)
    construcao = Construcao.new(**atributos)
    camadas = [ { materia_prima: superficie[0], lado: superficie[1], do_cliente: superficie[2]&.fetch(:do_cliente, false) || false } ]
    camadas += bases.map { |material, ligante, dono| { materia_prima: material, ligante: ligante, do_cliente: dono&.fetch(:do_cliente, false) || false } }
    construcao.definir_camadas(camadas)
    construcao
  end
end

RSpec.configure { |config| config.include Construcoes }
