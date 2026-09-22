require "rails_helper"
require "open3"

# Exercises bin/check-residues as a black box (it's a standalone script, not
# app code): run the real binary against the real repo, using throwaway
# untracked/orphan fixtures to trigger individual checks without touching
# anything else the guard scans (code residue, tmp/debug_*, DB records).
RSpec.describe "bin/check-residues" do
  let(:script) { Rails.root.join("bin", "check-residues").to_s }
  let(:leftover) { Rails.root.join("e2e", "check-residues-spec-leftover.dxf") }

  after { FileUtils.rm_f(leftover) }

  def run_check(*args)
    Open3.capture3(script, *args)
  end

  # Not a general "exits 0" assertion: other checks (e.g. Debug*-named DB
  # records left by a concurrent run) could legitimately be dirty at the
  # same time. Scoped to what this test actually controls — no e2e/
  # finding — so it doesn't flake on unrelated checks.
  it "reports no e2e/ finding when nothing is left over there" do
    stdout, = run_check("--list")
    expect(stdout).not_to match(%r{^\s*e2e/})
  end

  it "flags an untracked e2e/ file and exits 1" do
    FileUtils.touch(leftover)

    stdout, _stderr, status = run_check
    expect(status.success?).to be false
    expect(stdout).to include("e2e/check-residues-spec-leftover.dxf")
  end

  it "--list reports the finding but still exits 0" do
    FileUtils.touch(leftover)

    stdout, _stderr, status = run_check("--list")
    expect(status.success?).to be true
    expect(stdout).to include("e2e/check-residues-spec-leftover.dxf")
  end

  it "does not flag tracked e2e/ fixtures" do
    stdout, = run_check("--list")
    expect(stdout).not_to include("e2e-size-test.dxf")
  end

  # Regression: storage/stamps/ (real dev/prod uploads) and
  # storage/test_stamps/ (RSpec/E2E-only) used to be the same directory —
  # see ArquivoVersion::STORAGE_BASE and this branch's commit message.
  describe "check 4 (storage/stamps orphans, development DB only)" do
    let(:fake_uuid) { "check-residues-spec-fake-uuid" }
    let(:orphan_dir) { Rails.root.join("storage", "stamps", fake_uuid) }

    # check 4 shells out to `bin/rails runner ... development`, so this check
    # is only exercisable when storage/development.sqlite3 exists with the
    # current schema. CI never prepares it (only `db:test:prepare` runs) —
    # bin/check-residues itself handles that gracefully (see AGENTS.md: "DB
    # checks are skipped gracefully when a database is not prepared"), so
    # prepare it here rather than let the check silently no-op mid-assertion.
    # Locally this is a no-op against the real, already-migrated dev DB.
    before(:all) do
      system({ "RAILS_ENV" => "development" }, "bin/rails", "db:prepare", chdir: Rails.root.to_s, out: File::NULL, err: File::NULL)
    end

    after { FileUtils.rm_rf(orphan_dir) }

    it "flags a storage/stamps folder with no matching development Arquivo" do
      FileUtils.mkdir_p(orphan_dir)

      stdout, = run_check("--list")
      expect(stdout).to include("storage/stamps/#{fake_uuid}")
    end

    it "never reports storage/test_stamps/ (RSpec/E2E-only, always disposable)" do
      stdout, = run_check("--list")
      expect(stdout).not_to match(%r{storage/test_stamps})
    end
  end
end
