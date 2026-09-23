require "rails_helper"

RSpec.describe ArquivoBatchDestroyService do
  def storage_dir(arquivo)
    File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid)
  end

  it "destroys every deletable arquivo and returns their uuids" do
    a, b = create(:arquivo), create(:arquivo)
    destroyed, errors = described_class.call([ a.uuid, b.uuid ])
    expect(destroyed).to contain_exactly(a.uuid, b.uuid)
    expect(errors).to be_empty
    expect(Arquivo.where(id: [ a.id, b.id ])).to be_empty
  end

  it "reports unknown uuids as errors" do
    _destroyed, errors = described_class.call([ "no-such-uuid" ])
    expect(errors).to eq([ "no-such-uuid" ])
  end

  it "reports a blocked arquivo without undoing the others" do
    corte = create(:arquivo, :corte)
    create(:arquivo, tamanho: create(:tamanho, arquivo: corte))
    plain = create(:arquivo)

    destroyed, errors = described_class.call([ corte.uuid, plain.uuid ])

    expect(destroyed).to eq([ plain.uuid ])
    expect(errors).to match([ { uuid: corte.uuid, error: a_string_including("vinculado") } ])
    expect(Arquivo.exists?(corte.id)).to be true
  end

  it "removes storage folders only for destroyed arquivos" do
    corte = create(:arquivo, :corte)
    create(:arquivo, tamanho: create(:tamanho, arquivo: corte))
    plain = create(:arquivo)
    [ corte, plain ].each { |x| FileUtils.mkdir_p(storage_dir(x)) }

    described_class.call([ corte.uuid, plain.uuid ])

    expect(Dir.exist?(storage_dir(plain))).to be false
    expect(Dir.exist?(storage_dir(corte))).to be true
  ensure
    FileUtils.rm_rf(storage_dir(corte)) if corte
  end
end
