require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5a (decided 03/11/2026): a meter of dublado takes 1 m of each
# layer, from its owner, and of each ligante, the empresa's.
RSpec.describe ComponentesDaDublagem do
  let(:client) { create(:client) }
  let(:oxford) { material_de_dublagem("Oxford", largura: "1.60 m") }
  let(:filme) { material_de_dublagem("Filme", tipo: "filme", micras: 25) }

  def componentes(construcao) = described_class.new(construcao).map { |c| [ c.materia_prima, c.client, c.por_metro ] }

  it "joins the same material and owner twice (Oxford over Oxford) into 2 m a meter" do
    construcao = montar_construcao([ oxford, "trama" ], [ oxford, filme ]).tap(&:save!)

    expect(componentes(construcao)).to eq([ [ oxford, nil, 2 ], [ filme, nil, 1 ] ])
  end

  it "takes a client's layer from him, and leaves out a ligação with no ligante" do
    lona = material_de_dublagem("Lona")
    construcao = montar_construcao([ oxford, "trama" ], [ lona, nil, { do_cliente: true } ], client: client).tap(&:save!)

    expect(componentes(construcao)).to eq([ [ oxford, nil, 1 ], [ lona, client, 1 ] ])
    expect(described_class.new(construcao).sem_ligante).to eq(1)
  end

  it "says which component the balance doesn't cover, and by how much" do
    construcao = montar_construcao([ oxford, "trama" ], [ oxford, filme ]).tap(&:save!)
    MovimentoEstoque.create!(materia_prima: oxford, da_empresa: true, tipo: "entrada", quantidade: 15)
    MovimentoEstoque.create!(materia_prima: filme, da_empresa: true, tipo: "entrada", quantidade: 10)

    faltas = described_class.new(construcao).faltas(10, SaldosDeEstoque.call)
    expect(faltas.map { |c| [ c.materia_prima, c.falta ] }).to eq([ [ oxford, 5.0 ] ])
  end
end
