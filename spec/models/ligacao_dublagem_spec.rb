require "rails_helper"
require_relative "../support/construcoes"

# Rede editável 2/2a (decided 10/11/2026): a ligação goes to the trash and
# back (Q5a), each a line of its histórico (Q3a), and the network stops
# reading it while there.
RSpec.describe LigacaoDublagem do
  before { importar_rede_de_dublagens }

  let(:oxford) { GrupoMaterial.find_by!(nome: "Oxford") }
  let(:lona) { GrupoMaterial.find_by!(nome: "Lona") }
  let(:ligacao) { described_class.do_par(oxford, lona).sole }

  it "is named by its pair and lado" do
    expect(ligacao.nome).to eq("Oxford com Lona")
    expect(described_class.new(grupo_a: oxford, grupo_b: lona, lado: "trama").nome).to eq("Oxford com Lona (lado trama)")
  end

  it "reads as its page shows it: lado, momento, ligantes, a situação's, what is to confirm" do
    expect(ligacao.resumo).to eq("lado" => "qualquer", "dubla" => "antes", "ligantes" => [ "Filme 35 µm ou mais" ],
                                 "situacoes" => { "Tecido molha" => [ "Filme PU" ] }, "a_confirmar" => [ "situações" ])
  end

  it "goes to the trash and back, a line of its histórico each time, the network not reading it meanwhile" do
    usuario = create(:user)
    ligacao.excluir!(changed_by: "127.0.0.1", user: usuario)
    expect(RedeDeDublagens.ligacao("Oxford", "Lona")).to be_nil

    ligacao.restaurar!(changed_by: "127.0.0.1", user: usuario)
    expect(RedeDeDublagens.ligacao("Oxford", "Lona").uuid).to eq(ligacao.uuid)
    expect(ligacao.alteracoes.map { |linha| [ linha.texto, linha.user ] }).to eq([ [ "restaurou", usuario ], [ "mandou para a lixeira", usuario ] ])
  end

  # The same pair and lado once among the active ones: a new one may take the
  # trashed one's place, and then the trashed one can't come back.
  it "lets a new ligação take a trashed one's place, then refuses restoring the old one" do
    ligacao.excluir!(changed_by: "127.0.0.1")
    nova = described_class.new(grupo_a: lona, grupo_b: oxford, dubla: "depois")
    nova.ligantes.build(grupo_material: GrupoMaterial.find_by!(nome: "Cola"), posicao: 1)
    nova.save!

    expect { ligacao.restaurar!(changed_by: "127.0.0.1") }.to raise_error(ActiveRecord::RecordInvalid, /Oxford com Lona já está na rede/)
    expect(ligacao.reload).to be_excluido
  end
end
