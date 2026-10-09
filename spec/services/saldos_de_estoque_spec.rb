require "rails_helper"

# Etapa 2.3 (decided 09/10/2026): balances in meters, by owner.
RSpec.describe SaldosDeEstoque do
  let(:material) { MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Oxford"), cor_material: CorMaterial.create!(nome: "Azul"), largura: "1.40 m", gramatura: "100g") }
  let(:mks) { create(:client, name: "MKS") }
  let(:fagner) { create(:client, name: "Fagner") }

  def movimento(tipo, quantidade, client: nil)
    MovimentoEstoque.create!(materia_prima: material, tipo: tipo, quantidade: quantidade, client: client, da_empresa: client.nil?)
  end

  it "splits each material's balance into the empresa's own stock and each client's" do
    movimento("entrada", 100)
    movimento("saida", 12.5)
    movimento("entrada", 30, client: mks)
    movimento("entrada", 5, client: fagner)
    movimento("saida", 2, client: fagner)
    saldos = described_class.call
    expect([ saldos.empresa(material), saldos.por_cliente(material).transform_keys(&:name), saldos.total(material) ]).to eq([ 87.5, { "Fagner" => 3.0, "MKS" => 30.0 }, 120.5 ])
  end

  it "is zero for a material without movements" do
    expect([ described_class.call.empresa(material), described_class.call.por_cliente(material) ]).to eq([ 0.0, {} ])
  end
end
