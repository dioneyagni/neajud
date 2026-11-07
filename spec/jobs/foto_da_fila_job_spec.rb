require "rails_helper"

# Painel 3/4b (Q2a): every 5 minutes, the photo of the turno under way.
RSpec.describe FotoDaFilaJob do
  include ActiveSupport::Testing::TimeHelpers

  it "takes the photo of the turno under way, once" do
    travel_to Time.zone.parse("2026-11-04 10:00")
    Turno.create!(nome: "Dia", inicio: "00:00", fim: "23:59", dias: (0..6).to_a)

    expect { described_class.perform_now }.to change(FotoDaFila, :count).by(1)
    expect { described_class.perform_now }.not_to change(FotoDaFila, :count)
  end

  it "is scheduled in production, and in development only when asked" do
    agenda = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))

    expect(agenda.dig("production", "foto_da_fila", "class")).to eq("FotoDaFilaJob")
    expect(agenda).not_to have_key("development")
  end
end
