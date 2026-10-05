require "rails_helper"

RSpec.describe JuntarArtesService do
  around do |example|
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = :inline
  end

  let(:client) { create(:client) }
  let(:molde) { create(:molde, client: client) }

  it "moves every file of the origin, trashed ones too, and they take the destination's fields" do
    destino = create(:arquivo, molde: molde, nome: "ARCOVERDE", tamanho_rotulo: "P")
    origem = create(:arquivo, nome: "Arcoverde M", tamanho_rotulo: "M")
    lixo = create(:arquivo, arte: origem.arte).tap { |a| a.excluir!(changed_by: "spec") }

    expect(described_class.call(origem: origem, destino: destino)).to eq(destino.arte)
    expect([ origem.reload, lixo.reload ].map(&:arte_id)).to eq([ destino.arte_id ] * 2)
    expect(origem.attributes.values_at("molde_id", "client_id", "nome")).to eq([ molde.id, client.id, "ARCOVERDE" ])
  end

  it "refuses moving files to another molde or client, naming both" do
    origem = create(:arquivo, molde: molde)
    expect { described_class.call(origem: origem, destino: create(:arquivo, molde: create(:molde))) }
      .to raise_error(JuntarArtesService::Recusado, /molde #{Regexp.escape(molde.nome.inspect)}/)
    expect { described_class.call(origem: create(:arquivo, client: client), destino: create(:arquivo, client: create(:client))) }
      .to raise_error(JuntarArtesService::Recusado, /client/)
  end

  it "refuses joining an arte into itself or a corte" do
    arquivo = create(:arquivo)
    irmao = create(:arquivo, arte: arquivo.arte)
    expect { described_class.call(origem: arquivo, destino: irmao) }.to raise_error(JuntarArtesService::Recusado, /already in this arte/)
    expect { described_class.call(origem: arquivo, destino: create(:arquivo, :corte)) }.to raise_error(JuntarArtesService::Recusado, /must both be artes/)
  end
end
