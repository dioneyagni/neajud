require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5b1a: the construção's form — cards of a material or an earlier
# card above and below — read back as the layers and the dublagem of each.
RSpec.describe MontagemDaChave do
  let(:oxford) { material_de_dublagem("Oxford", cor: "Preto") }
  let(:lona) { material_de_dublagem("Lona") }
  let(:espuma) { material_de_dublagem("Espuma", densidade: "TC4") }
  let(:helanca) { material_de_dublagem("Helanca") }
  let(:eva) { material_de_dublagem("EVA") }
  let(:filme) { material_de_dublagem("Filme", tipo: "filme", micras: 35) }

  def lado(escolha, **outros) = { "escolha" => escolha }.merge(outros.transform_keys(&:to_s))

  # The canvas's chave: DUB-A Oxford/Lona, DUB-B Espuma/Helanca, DUB-C =
  # DUB-B/EVA, DUB-D = DUB-A/DUB-C, in the order the form draws them.
  let(:cards) do
    [ { "cima" => lado(oxford.uuid, lado: "avesso"), "baixo" => lado(lona.uuid, do_cliente: "1"), "ligante_uuid" => filme.uuid },
      { "cima" => lado(espuma.uuid), "baixo" => lado(helanca.uuid) },
      { "cima" => lado("dublagem:1"), "baixo" => lado(eva.uuid) },
      { "cima" => lado("dublagem:0"), "baixo" => lado("dublagem:2"), "posicao" => "1" } ]
  end

  def camadas(cards = self.cards, acao: nil) = described_class.new(cards, acao: acao, materiais: MateriaPrima.all).camadas

  def resumo(lista) = lista.map { |camada| [ camada[:materia_prima]&.grupo_material&.nome, camada[:ordem_da_dublagem] ] }

  it "reads the layers top to bottom, each base with the dublagem that joins it to the one above" do
    lista = camadas

    expect(resumo(lista)).to eq([ [ "Oxford", nil ], [ "Lona", 1 ], [ "Espuma", 3 ], [ "Helanca", 1 ], [ "EVA", 2 ] ])
    expect(lista.first).to include(lado: "avesso", do_cliente: false)
    expect(lista.second).to include(ligante: filme, do_cliente: true)
  end

  it "keeps a card used twice with the first, and never lets a card inside itself" do
    duas_vezes = cards.first(3) + [ { "cima" => lado("dublagem:1"), "baixo" => lado(eva.uuid) } ]
    expect(resumo(camadas(duas_vezes))).to eq([ [ "Oxford", nil ], [ "Lona", 1 ], [ "Espuma", nil ], [ "Helanca", 1 ], [ "EVA", 2 ], [ nil, nil ], [ "EVA", 1 ] ])

    ciclo = [ { "cima" => lado("dublagem:1"), "baixo" => lado(lona.uuid) }, { "cima" => lado("dublagem:0"), "baixo" => lado(eva.uuid) } ]
    expect(resumo(camadas(ciclo))).to eq([ [ nil, nil ], [ "EVA", 1 ], [ "Lona", 2 ] ])
  end

  # The E2E found it: a new card (posicao 6) taking DUB-A (posicao 1) went
  # under DUB-C's piece (posicao 3), turning the stack upside down.
  it "puts a card that took the letra on top above the other loose pieces" do
    soltos = [ cards[0].merge("posicao" => "1"), cards[1].merge("posicao" => "3"), { "cima" => lado("dublagem:0"), "baixo" => lado(""), "posicao" => "6" },
               { "cima" => lado("dublagem:1"), "baixo" => lado(eva.uuid), "posicao" => "3" } ]

    expect(resumo(camadas(soltos)).map(&:first)).to eq([ "Oxford", "Lona", nil, "Espuma", "Helanca", "EVA" ])
  end

  # 11/11/2026 (Q2a): the momento a card picked goes to its junction; a card
  # that picked none sends none, so a construção in use keeps its own.
  it "takes the momento a card picked to the layer it joins" do
    escolhidos = [ cards[0].merge("dubla" => "depois"), *cards.drop(1) ]
    lista = camadas(escolhidos)

    expect(lista.second[:dubla]).to eq("depois")
    expect(lista.drop(2).map { |camada| camada.key?(:dubla) }).to all(be(false))
  end

  it "adds an empty card at the end" do
    expect(resumo(camadas(acao: "nova")).last(2)).to eq([ [ nil, nil ], [ nil, 1 ] ])
  end

  # Without the EVA, DUB-C's place is DUB-B's (the canvas's note).
  it "takes a material out of a card inside another: the card gives way to its other side" do
    expect(resumo(camadas(acao: "tirar-2-baixo"))).to eq([ [ "Oxford", nil ], [ "Lona", 1 ], [ "Espuma", 2 ], [ "Helanca", 1 ] ])
  end

  it "takes a letra out of a card standing alone: the side empties and the letra goes loose, keeping its place" do
    expect(resumo(camadas(acao: "tirar-3-cima"))).to eq([ [ "Oxford", nil ], [ "Lona", 1 ], [ nil, nil ], [ "Espuma", 3 ], [ "Helanca", 1 ], [ "EVA", 2 ] ])
    expect(resumo(camadas(acao: "tirar-3-baixo"))).to eq([ [ "Oxford", nil ], [ "Lona", 1 ], [ nil, 2 ], [ "Espuma", nil ], [ "Helanca", 1 ], [ "EVA", 2 ] ])
  end

  it "gives the top layer the trama side when none was chosen" do
    expect(camadas([ { "cima" => lado(oxford.uuid), "baixo" => lado(lona.uuid) } ]).first[:lado]).to eq("trama")
  end
end
