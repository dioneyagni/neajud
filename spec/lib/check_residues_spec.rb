require "rails_helper"
require "open3"

# Exercises bin/check-residues as a black box (it's a standalone script, not
# app code): run the real binary against the real repo, using a throwaway
# untracked file to trigger check 5 without touching anything else the guard
# scans (code residue, tmp/debug_*, DB records, storage/stamps).
RSpec.describe "bin/check-residues" do
  let(:script) { Rails.root.join("bin", "check-residues").to_s }
  let(:leftover) { Rails.root.join("e2e", "check-residues-spec-leftover.dxf") }

  after { FileUtils.rm_f(leftover) }

  def run_check(*args)
    Open3.capture3(script, *args)
  end

  # Not a general "exits 0" assertion: sibling request specs upload real
  # files into storage/stamps/ outside the DB transaction, so check 4 can
  # legitimately still be dirty mid-suite (it's only reconciled once, in
  # rails_helper's after(:suite)). Scoped to what this test actually
  # controls — no e2e/ finding — so it doesn't flake on unrelated checks.
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
end
