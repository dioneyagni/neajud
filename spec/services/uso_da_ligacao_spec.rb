require "rails_helper"
require_relative "../support/construcoes"

# Rede editável 2/2a: "Onde ela é usada" and the warning before the trash.
RSpec.describe UsoDaLigacao do
  let(:oxford) { material_de_dublagem("Oxford") }
  let(:lona) { material_de_dublagem("Lona") }
  let(:eva) { material_de_dublagem("EVA") }
  let(:filme) { material_de_dublagem("Filme", tipo: "filme", micras: 35) }
  let(:ligacao) { LigacaoDublagem.do_par(oxford.grupo_material, lona.grupo_material).sole }

  it "finds the construções joining its pair, not the trashed ones, even with the ligação in the trash" do
    usa = montar_construcao([ oxford, "trama" ], [ lona, filme ]).tap(&:save!)
    montar_construcao([ oxford, "trama" ], [ eva, material_de_dublagem("Filme", tipo: "filme", micras: 25) ]).save!
    montar_construcao([ oxford, "avesso" ], [ lona, filme ]).tap(&:save!).excluir!(changed_by: "127.0.0.1")
    ligacao.excluir!(changed_by: "127.0.0.1")

    expect(described_class.new(ligacao, construcoes: Construcao.all).call).to eq([ usa ])
  end

  it "with a lado, only where the superfície is on it" do
    trama = montar_construcao([ oxford, "trama" ], [ lona, filme ]).tap(&:save!)
    montar_construcao([ oxford, "avesso" ], [ lona, filme ]).save!
    ligacao.update_columns(lado: "trama")

    expect(described_class.new(ligacao, construcoes: Construcao.all).call).to eq([ trama ])
  end
end
