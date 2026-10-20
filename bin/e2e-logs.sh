# Logs kept per run, so an intermittent failure can still be investigated
# after later runs (a single /tmp/neajud_server.log used to be overwritten):
#   requests.log — this run's slice of log/test.log (the Rails request log;
#                  in the test env requests are NOT written to stdout)
#   server.log   — the server process's stdout/stderr (boot, Puma, crashes)
# A spec marker is appended to both before each spec. Keeps the last
# E2E_LOG_KEEP runs; log/e2e/latest → newest.
E2E_LOG_ROOT="${E2E_LOG_ROOT:-log/e2e}"
E2E_LOG_KEEP=10
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
RUN_LOG_DIR="$E2E_LOG_ROOT/$RUN_ID"
SERVER_LOG="$RUN_LOG_DIR/server.log"
REQUESTS_LOG="$RUN_LOG_DIR/requests.log"
RAILS_TEST_LOG="${RAILS_TEST_LOG:-log/test.log}"
# The inode of the run's test.log: another one at the end means Rails
# rotated it during the run.
RUN_LOG_INODE=""

prepare_run_log() {
  mkdir -p "$RUN_LOG_DIR"
  : > "$SERVER_LOG"
  ln -sfn "$RUN_ID" "$E2E_LOG_ROOT/latest"
  find "$E2E_LOG_ROOT" -mindepth 1 -maxdepth 1 -type d -name '2*' | sort | head -n -"$E2E_LOG_KEEP" | xargs -r rm -rf
  start_rails_test_log
  trap save_requests_log EXIT
}

# Rails rotates log/test.log at 100 MB (config.log_file_size's default in
# test): it becomes test.log.0 and a new file starts. The run's slice used to
# be cut at a byte offset of the old file, past the new one's end, so every
# requests.log came out empty (17-19/10/2026). Each run starts on a fresh
# file instead — the old one rotated by hand, as Rails would.
start_rails_test_log() {
  if [ -s "$RAILS_TEST_LOG" ]; then mv -f "$RAILS_TEST_LOG" "$RAILS_TEST_LOG.0"; fi
  : > "$RAILS_TEST_LOG"
  RUN_LOG_INODE="$(stat -c %i "$RAILS_TEST_LOG")"
}

# Rails' logger opens log/test.log in append mode, so these lines interleave
# with request logs instead of overwriting them.
mark_spec() {
  local marker="=== [$(date +%T)] spec: $1 ==="
  echo "$marker" >> "$SERVER_LOG"
  echo "$marker" >> "$RAILS_TEST_LOG"
}

# Runs on any exit (success, failure, aborted startup). A run that went past
# 100 MB was rotated: its start is in test.log.0.
save_requests_log() {
  [ -n "$RUN_LOG_INODE" ] || return 0
  {
    if [ "$(stat -c %i "$RAILS_TEST_LOG" 2>/dev/null)" != "$RUN_LOG_INODE" ]; then cat "$RAILS_TEST_LOG.0"; fi
    cat "$RAILS_TEST_LOG"
  } > "$REQUESTS_LOG" 2>/dev/null || true
}
