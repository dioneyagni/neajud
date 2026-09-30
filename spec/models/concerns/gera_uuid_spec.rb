require "rails_helper"

# Etapa 1.1 (1/2): every entity has a uuid, and it is the only identifier that
# leaves the server.
RSpec.describe GeraUuid do
  # One per table that got its uuid in AddUuidToRemainingTables; the older
  # ones (arquivos, pedidos, users…) are covered by their own specs.
  entidades = {
    client: -> { FactoryBot.create(:client) },
    modelo: -> { FactoryBot.create(:modelo) },
    molde: -> { FactoryBot.create(:molde) },
    peca: -> { FactoryBot.create(:peca) },
    tamanho: -> { FactoryBot.create(:tamanho) },
    modelo_peca: -> { FactoryBot.create(:modelo_peca) },
    item_pedido_peca: -> { FactoryBot.create(:item_pedido_peca) },
    grupo_material: -> { GrupoMaterial.create!(nome: "Grupo #{SecureRandom.hex(3)}") },
    cor_material: -> { CorMaterial.create!(nome: "Cor #{SecureRandom.hex(3)}") },
    cut_layer: -> { CutLayer.create!(arquivo_version: FactoryBot.create(:arquivo_version), layer_name: "0", color: 7, annotation: "cut") },
    materia_prima: -> { materia_prima_nova },
    movimento_estoque: -> { MovimentoEstoque.create!(client: FactoryBot.create(:client), materia_prima: materia_prima_nova, tipo: "entrada", quantidade: 1) },
    exclusao_log: -> { FactoryBot.create(:client).tap { |c| c.excluir!(changed_by: "10.0.0.1") }.exclusao_logs.last }
  }

  def self.materia_prima_nova
    MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "G #{SecureRandom.hex(3)}"),
                         cor_material: CorMaterial.create!(nome: "C #{SecureRandom.hex(3)}"), largura: "1.40", gramatura: "100g")
  end

  entidades.each do |nome, criar|
    it "gives a new #{nome} a uuid and uses it as the URL param" do
      registro = criar.call
      expect(registro.uuid).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      expect(registro.to_param).to eq(registro.uuid)
    end
  end

  it "keeps a uuid given on create" do
    uuid = SecureRandom.uuid
    expect(create(:client, uuid: uuid).uuid).to eq(uuid)
  end

  describe ".por_uuid!" do
    it "finds by uuid, also inside a relation" do
      client = create(:client)
      expect(Client.por_uuid!(client.uuid)).to eq(client)
      expect(Client.ativos.por_uuid!(client.uuid)).to eq(client)
    end

    # The integer id must not work as an identifier (a guessable sequence).
    it "raises RecordNotFound for an unknown uuid or an integer id" do
      client = create(:client)
      expect { Client.por_uuid!("nao-existe") }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Client.por_uuid!(client.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
