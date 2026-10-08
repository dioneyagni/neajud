require "rails_helper"

# Etapa 2.2 (1/3, decided 08/10/2026): how a corte's pieces may turn in the fit.
RSpec.describe GiroNoEncaixe do
  it "starts unmarked and takes only nenhum, 180 or 90, naming a wrong value" do
    corte = create(:arquivo, :corte)
    expect([ corte.giro, corte.valid? ]).to eq([ nil, true ])
    corte.giro = "45"
    expect(corte).not_to be_valid
    expect(corte.errors[:giro].first).to include("45 is not a turn")
  end

  it "recomputes the sizes' meters per piece when the turn changes" do
    ActiveJob::Base.queue_adapter = :test
    corte = create(:arquivo, :corte)
    tamanho = create(:tamanho, arquivo: corte)
    allow(MateriaPrima).to receive(:larguras_mm).and_return([ 1400 ])
    expect { corte.definir_giro!("90") }.to have_enqueued_job(MetrosPorPecaJob).with([ tamanho.id ], [ 1400 ], refazer: true)
    expect(corte.reload.giro).to eq("90")
  ensure
    ActiveJob::Base.queue_adapter = :inline
  end
end
