require "rails_helper"

RSpec.describe ArquivoBatchDestroyService do
  def storage_dir(arquivo)
    File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid)
  end

  it "moves every arquivo to the trash and returns their uuids" do
    a, b = create(:arquivo), create(:arquivo)
    trashed, errors = described_class.call([ a.uuid, b.uuid ], changed_by: "10.0.0.1")
    expect(trashed).to contain_exactly(a.uuid, b.uuid)
    expect(errors).to be_empty
    expect(Arquivo.excluidos.where(id: [ a.id, b.id ]).count).to eq(2)
    expect(a.exclusao_logs.last.changed_by).to eq("10.0.0.1")
  end

  it "reports unknown and already-trashed uuids as errors without undoing the others" do
    trashed = create(:arquivo, deleted_at: 1.day.ago)
    plain = create(:arquivo)
    done, errors = described_class.call([ "no-such-uuid", trashed.uuid, plain.uuid ], changed_by: "10.0.0.1")
    expect(done).to eq([ plain.uuid ])
    expect(errors).to eq([ "no-such-uuid", trashed.uuid ])
  end

  it "keeps the storage folders (nothing is physically deleted)" do
    plain = create(:arquivo)
    FileUtils.mkdir_p(storage_dir(plain))

    described_class.call([ plain.uuid ], changed_by: "10.0.0.1")

    expect(Dir.exist?(storage_dir(plain))).to be true
  ensure
    FileUtils.rm_rf(storage_dir(plain)) if plain
  end
end
