require_relative "tecidos"

# Materials of the dublagem network for the construção's specs (Dublagem
# 3/5): each group with the roles db/seeds/rede_de_dublagens.yml gives, and a
# construção built from layers.
# Usage: oxford = material_de_dublagem("Oxford", preco: 20)
#        filme = material_de_dublagem("Filme", tipo: "filme", micras: 35, preco: 3)
#        construcao = montar_construcao([ oxford, "trama" ], [ lona, filme ], preco_final: 46)
module Construcoes
  PAPEIS = { "Oxford" => %i[superficie base], "Telinha" => %i[superficie], "Lona" => %i[base], "EVA" => %i[base],
             "Espuma" => %i[base], "Helanca" => %i[base], "Filme" => [], "Filme PU" => [],
             "Microfibra" => %i[superficie base], "Cetim" => %i[superficie base], "Cola" => [] }.freeze

  # Rede editável 1/2: the network lives in the database, and db/seeds.rb
  # skips the test environment (a global import would clash with specs that
  # create "Oxford" themselves). A spec that dubs gets the initial network
  # with its first material; one that reads the network alone calls this.
  # The groups come first, asking no attribute, so a spec's material needs no
  # gramatura; the import then finds them.
  # Usage: importar_rede_de_dublagens
  def importar_rede_de_dublagens
    @rede_de_dublagens_importada ||= begin
      PAPEIS.each_key { |nome| grupo_de_dublagem(nome) }
      ImportarRedeDeDublagens.new.call
    end
  end

  def material_de_dublagem(grupo, tipo: "tecido", cor: "Branco", largura: "1.40 m", micras: nil, densidade: nil, preco: nil)
    importar_rede_de_dublagens
    MateriaPrima.create!(grupo_material: grupo_de_dublagem(grupo), cor_material: CorMaterial.find_or_create_by!(nome: cor), tipo: tipo,
                         largura: largura, micras: micras, densidade: densidade, preco_metro: preco)
  end

  def grupo_de_dublagem(nome)
    papeis = PAPEIS.fetch(nome)
    GrupoMaterial.create_with(superficie: papeis.include?(:superficie), base: papeis.include?(:base), atributos: {}).find_or_create_by!(nome: nome)
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

  # Dublagem 5a: a confirmed tecido pedido whose corrida is dubbed into the
  # construção, its stock out taken (the dublado, from the construção's owner).
  # Usage: pedido = pedido_dublado_confirmado(construcao, metros: 10)
  def pedido_dublado_confirmado(construcao, metros: 10, client: construcao.client || create(:client))
    pedido = create(:pedido, client: client, tipo: "tecido")
    arquivo = criar_obra_de_tecido("corrida", client: client).arquivos.first
    create(:item_pedido, pedido: pedido, arquivo: arquivo, materia_prima: construcao.superficie.materia_prima, construcao: construcao, metros: metros)
    pedido.update!(status: "confirmado")
    SaidaDoPedido.call(pedido)
    pedido.reload
  end
end

RSpec.configure { |config| config.include Construcoes }

# Each example reads the network afresh: its rows roll back with the
# example, while Current may outlive it.
RSpec.configure { |config| config.before { RedeDeDublagens.esquecer } }
