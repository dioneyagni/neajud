require "rails_helper"
require_relative "../support/fake_organizador_dxf"
require_relative "../support/fake_encaixe"

RSpec.describe MetrosPorPecaJob do
  let(:encaixe) { FakeEncaixe.new }

  before { described_class.encaixe = encaixe }
  after { described_class.encaixe = EncaixeDoTamanho }

  it "computes each size on each width" do
    a, b = create(:tamanho), create(:tamanho)
    described_class.perform_now([ a.id, b.id ], [ 1400, 1600 ])
    expect(encaixe.chamadas).to eq([ [ a.id, 1400 ], [ a.id, 1600 ], [ b.id, 1400 ], [ b.id, 1600 ] ])
  end

  # The size's DXF was extracted again: the old fits no longer hold.
  it "clears the old values first when asked to redo" do
    tamanho = create(:tamanho, metros_por_peca: { "1250" => 0.5 })
    described_class.perform_now([ tamanho.id ], [], refazer: true)
    expect(tamanho.reload.metros_por_peca).to eq({})
  end

  it "is queued after a corte's sizes are prepared, on the materials' widths, redoing them" do
    ActiveJob::Base.queue_adapter = :test
    PreparacaoTamanhosJob.organizador = FakeOrganizadorDxf.new
    corte = create(:arquivo, :corte)
    tamanho = create(:tamanho, arquivo: corte)
    allow(MateriaPrima).to receive(:larguras_mm).and_return([ 1250 ])
    allow_any_instance_of(Arquivo).to receive(:broadcast_refresh)
    expect { PreparacaoTamanhosJob.perform_now(corte.id, false) }
      .to have_enqueued_job(described_class).with([ tamanho.id ], [ 1250 ], refazer: true)
  ensure
    PreparacaoTamanhosJob.organizador = DxfOrganizationService
    ActiveJob::Base.queue_adapter = :inline
  end
end
