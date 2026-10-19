require "rails_helper"
require "open3"

# bin/e2e-logs.sh: each E2E run keeps its slice of log/test.log. Rails
# rotates that file at 100 MB, and the slice — cut at a byte offset of the
# old file — came out empty on every run for days (17-19/10/2026).
RSpec.describe "bin/e2e-logs.sh" do
  let(:pasta) { Dir.mktmpdir }
  let(:log) { File.join(pasta, "test.log") }

  after { FileUtils.rm_rf(pasta) }

  # Runs the script's functions in a shell over a temporary log; `meio` is
  # what happens while the specs run. Returns the run's requests.log.
  def rodada(meio)
    script = <<~BASH
      set -e
      export RAILS_TEST_LOG=#{log.shellescape} E2E_LOG_ROOT=#{File.join(pasta, "e2e").shellescape}
      source #{Rails.root.join("bin/e2e-logs.sh").to_s.shellescape}
      prepare_run_log
      mark_spec exemplo
      #{meio}
      save_requests_log
      cat "$REQUESTS_LOG"
    BASH
    saida, erro, status = Open3.capture3("bash", "-c", script)
    raise "bin/e2e-logs.sh failed: #{erro}" unless status.success?

    saida
  end

  it "keeps only this run's requests, the earlier ones rotated away" do
    File.write(log, "Started GET \"/antes\"\n")
    saida = rodada(%(echo 'Started GET "/durante"' >> "$RAILS_TEST_LOG"))
    expect(saida).to match(/=== \[[\d:]+\] spec: exemplo ===\nStarted GET "\/durante"\n\z/)
    expect(File.read("#{log}.0")).to eq("Started GET \"/antes\"\n")
  end

  it "reads across a rotation during the run" do
    rotacao = <<~BASH
      echo 'Started GET "/antes-da-rotacao"' >> "$RAILS_TEST_LOG"
      mv "$RAILS_TEST_LOG" "$RAILS_TEST_LOG.0"
      echo 'Started GET "/depois-da-rotacao"' >> "$RAILS_TEST_LOG"
    BASH
    expect(rodada(rotacao)).to include("spec: exemplo", "/antes-da-rotacao", "/depois-da-rotacao")
  end
end
