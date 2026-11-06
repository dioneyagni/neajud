require "rails_helper"

# Painel 2/4a (decided 05/11/2026): the dono's turnos — hours, days, crossing
# midnight (Q10a) — never overlapping anywhere in the week.
RSpec.describe Turno do
  def turno(nome, inicio, fim, dias = (1..5).to_a)
    Turno.new(nome: nome, inicio: inicio, fim: fim, dias: dias)
  end

  it "takes the hours as typed and keeps them in minutes" do
    manha = turno("Manhã", "06:00", "14:00").tap(&:save!)
    expect([ manha.inicio_min, manha.fim_min, manha.horario, manha.horas ]).to eq([ 360, 840, "06:00–14:00", 8.0 ])
  end

  it "crosses midnight when it ends at or before its start" do
    noite = turno("Noite", "22:00", "06:00")
    expect([ noite.atravessa_meia_noite?, noite.horas, noite.valid? ]).to eq([ true, 8.0, true ])
  end

  it "refuses an hour that is not a time of day, and a turno that doesn't last" do
    expect(turno("X", "25:00", "06:00").tap(&:valid?).errors[:inicio_min]).to include("must be a time of day like 06:00")
    expect(turno("X", "06:00", "06:00").tap(&:valid?).errors[:fim].first).to include("is the same as the start")
  end

  it "needs at least one day of the week, 0 to 6" do
    expect(turno("X", "06:00", "14:00", []).tap(&:valid?).errors[:dias].first).to include("choose at least one day")
    expect(turno("X", "06:00", "14:00", [ "7" ]).tap(&:valid?).errors[:dias].first).to include("[7] are not days of the week")
    expect(turno("X", "06:00", "14:00", [ "", "1", "3" ]).tap(&:valid?).dias).to eq([ 1, 3 ])
  end

  it "refuses a name already used by another active turno" do
    turno("Manhã", "06:00", "14:00").save!
    expect(turno("manhã", "14:00", "22:00").tap(&:valid?).errors[:nome].first).to include("is already a turno")
  end

  it "refuses one that overlaps another, naming where they meet" do
    turno("Manhã", "06:00", "14:00", (1..6).to_a).save!
    tarde = turno("Tarde", "13:00", "22:00")
    expect(tarde.valid?).to be(false)
    expect(tarde.errors[:base].first).to include("overlaps Manhã 06:00–14:00 (seg a sáb) on seg 13:00")
    expect(turno("Tarde", "14:00", "22:00").valid?).to be(true)
  end

  it "checks the overlap across midnight and across Saturday night" do
    turno("Noite", "22:00", "06:00", [ 6 ]).save!
    expect(turno("Domingo", "05:00", "09:00", [ 0 ]).tap(&:valid?).errors[:base].first).to include("on dom 05:00")
    expect(turno("Domingo", "06:00", "09:00", [ 0 ]).valid?).to be(true)
  end

  it "doesn't compare with a trashed turno" do
    turno("Manhã", "06:00", "14:00").tap(&:save!).excluir!(changed_by: "spec")
    expect(turno("Outra manhã", "06:00", "14:00").valid?).to be(true)
  end

  it "comes back from the trash only if its hours are still free" do
    manha = turno("Manhã", "06:00", "14:00").tap(&:save!)
    manha.excluir!(changed_by: "spec")
    turno("Cedo", "07:00", "12:00").save!
    expect { manha.reload.restaurar!(changed_by: "spec") }.to raise_error(ActiveRecord::RecordInvalid, /overlaps Cedo/)
    expect(manha.reload.excluido?).to be(true)
  end

  it "names its days as a range when they follow each other" do
    expect(turno("A", "06:00", "14:00", (1..6).to_a).rotulo_dos_dias).to eq("seg a sáb")
    expect(turno("B", "06:00", "14:00", [ 1, 3, 5 ]).rotulo_dos_dias).to eq("seg, qua, sex")
  end
end
