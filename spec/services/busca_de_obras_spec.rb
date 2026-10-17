require "rails_helper"
require_relative "../support/tecidos"

# The DTF and tecido pedido pages' search (Etapa 2.6b1, 2.7a).
RSpec.describe BuscaDeObras do
  let(:client) { create(:client) }

  it "lists only the works of the pedido's type" do
    corrida = criar_obra_de_tecido("corrida", client: client)
    cor = criar_obra_de_tecido("cor_lisa", client: client)
    Arte.novo_do_tipo("dtf").tap(&:save!).then { |dtf| create(:arquivo, category: "artes", arte: dtf, client: client) }
    expect(described_class.call(Arquivo.all, "tecido", nil).map(&:arte)).to contain_exactly(corrida, cor)
  end

  it "finds by file name, number and a cor lisa's family, the letters narrowing the number" do
    laranja = criar_obra_de_tecido("cor_lisa", client: client, filename: "tom-a").tap { |a| a.update_columns(familia: "Laranja", numero: 2) }
    azul = criar_obra_de_tecido("cor_lisa", client: client, filename: "tom-b").tap { |a| a.update_columns(familia: "Azul", numero: 2) }
    buscar = ->(termo) { described_class.call(Arquivo.all, "tecido", termo).map(&:arte) }
    expect([ buscar.("laranja"), buscar.("Azul 2"), buscar.("tom-b") ]).to eq([ [ laranja ], [ azul ], [ azul ] ])
    expect(buscar.("2")).to contain_exactly(laranja, azul)
  end
end
