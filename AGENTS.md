# Neajud — AGENTS.md

## Code style

- Functions: 4-20 lines. Split if longer.
- Files: under 500 lines. Split by responsibility.
- One thing per function, one responsibility per module (SRP).
- Names: specific and unique. Avoid `data`, `handler`, `Manager`.
  Prefer names that return <5 grep hits in the codebase.
- Types: explicit. No `any`, no `Dict`, no untyped functions.
- No code duplication. Extract shared logic into a function/module.
- Early returns over nested ifs. Max 2 levels of indentation.
- Exception messages must include the offending value and expected shape.

## Comments

- Keep your own comments. Don't strip them on refactor — they carry
  intent and provenance.
- Write WHY, not WHAT. Skip `// increment counter` above `i++`.
- Docstrings on public functions: intent + one usage example.
- Reference issue numbers / commit SHAs when a line exists because
  of a specific bug or upstream constraint.

## Tests

- Full suite: `bin/rspec && bash bin/e2e` (must pass 100% before merge).
- Every public method gets an RSpec test; every user-visible flow gets an E2E
  test. Private helpers are covered through the public method that uses them.
  Bug fixes get a regression test that fails without the fix.
- Mock external I/O (API, DB, filesystem) with named fake classes,
  not inline stubs.
- Tests must be F.I.R.S.T: fast, independent, repeatable,
  self-validating, timely.
- Test the Rails server, observe any errors in the console and correct them,
  shut down and restart the server and all related processes. When there are
  no errors in the console, test e2e, then e2e --headed and check if
  everything goes through. Correct what is necessary and test again.
- An intermittent failure is never "noise". Before calling it unrelated to
  your change: run the suite N times on your branch and N times on `main`,
  compare failure rates, and check request ordering in `log/test.log`
  (e.g. a `Started GET` arriving before the previous POST's `Completed`).
  Fix the root cause or report it; don't retry until green.

### Job & image processing tests

- `spec/jobs/arquivo_processing_job_spec.rb` tests each conversion method
  (`generate_preview_rgb`, `generate_preview_cmyk`, `generate_preview_utif`,
  `generate_preview_dxf`, `detect_spots`, `process_image` routing).
- `generate_preview_dxf` outputs SVG, so its tests check: (1) strict-parsed
  `<svg>` root, (2) `viewBox` size within 0.5% of the source drawing,
  (3) rasterized output has opaque pixels (`png_max_alpha`, not
  `png_has_visible_pixels?` — DXF strokes are often pure black).
- Each conversion test **must** verify: (1) a valid PNG is produced,
  (2) dimensions match the source, (3) the PNG contains visible pixels
  (decompress IDAT and check non-zero alpha + RGB).
- CMYK spot via UTIF.js is a known limitation — test only file validity,
  not pixel content.
- `detect_spots` tests use real files from `spec/fixtures/files/` to verify
  spot detection accuracy (including `Transparency` filtering).

### E2E tests

- `e2e/arquivos-previews.spec.js` covers all 4 raster preview strategies: RGB no-spot,
  RGB spot, CMYK no-spot, CMYK spot.
- Each preview test **must** verify: (1) status is `processed`,
  (2) colorspace label matches expected, (3) preview image loads (200 OK,
  `image/*` content-type), (4) preview has visible pixels (load into canvas,
  check first 100x100 region for non-zero alpha + RGB).
- CMYK spot is exempt from pixel validation (UTIF.js limitation).
- Arquivo card selectors (CSS class is still `.stamp-card`) must match by
  **filename without extension** using
  `page.locator(".stamp-card").filter({ hasText: displayName })` to avoid
  flaky clicks on wrong cards when multiple arquivos exist.
- Run 3 times in succession to verify stability.
- **Uploads**: always use `uploadFileAndWait(page, pathOrPaths)` or
  `submitUploadAndWait(page, n)` from `e2e/support/upload.js`. They wait for
  `upload_controller.js` to report `Upload complete (N ok, 0 failed)`.
- **Wait for proof, not time**: never `waitForTimeout` after an action, and
  never `waitForSelector` on something that already existed before the action
  (e.g. `.stamp-card` from the pre-upload gallery). Wait for a signal the
  action produces: a status text, `page.waitForResponse`, a count that grew.
  This is what made "DXF Mold Organization" flaky (fixed in #76).
- **Asserting absence**: a test that checks something is *not* shown must say
  why in a comment (the business rule). Otherwise it can lock in a regression
  as expected behavior — "Size Selection: hidden by default…" did exactly
  that until #75.

### Preventing false positives

Tests that only check "does an image load at the URL" miss bugs where
the image is all-transparent or wrong colorspace. Every image conversion
test must validate **pixel content**, not just file existence.

## Dependencies

- Inject dependencies through constructor/parameter, not global/import.
- Wrap third-party libs behind a thin interface owned by this project.

## Structure

- Follow the framework's convention (Rails, Django, Next.js, etc.).
- Prefer small focused modules over god files.
- Predictable paths: controller/model/view, src/lib/test, etc.

## Formatting

- Use the language default formatter (`cargo fmt`, `gofmt`, `prettier`,
  `black`, `rubocop -A`). Don't discuss style beyond that.

## Logging

- Structured JSON when logging for debugging / observability.
- Plain text only for user-facing CLI output.


## Commands

```bash
bin/rspec                     # unit + request tests (RSpec)
bin/rubocop                   # lint (rubocop-rails-omakase)
bin/brakeman --exit-on-warn   # security scan
bin/check-residues            # guard: debug statements, tmp/debug_*, Debug* records, orphan stamps, e2e/ leftovers
bash bin/e2e                  # Playwright E2E (headless) — stops the dev server on :3000, see "bin/e2e stops the dev server"
bash bin/e2e --headed         # Playwright E2E (visible browser)
```

**Pre-commit** (the one command to run before every push; CI runs the same checks):
`bin/rspec && bin/rubocop && bin/brakeman --no-pager && bin/check-residues`

`bin/check-residues` exits 1 when any of these leaked into the repo:

1. Debug statements in `app/`/`lib/` (`binding.pry`, `byebug`, `debugger`, `console.log`/`console.debug`)
2. Orphan debug scripts under `tmp/` (`tmp/debug_*`, `tmp/*debug*/`)
3. Records named `Debug*` in the test + development databases
4. Orphan upload folders in `storage/stamps/` with no matching `Arquivo.uuid` in the development DB (`storage/test_stamps/` is RSpec/E2E-only and always disposable — not checked)
5. Untracked files in `e2e/` (temp DXF/TIF that a failed or aborted spec did not delete)

`bin/check-residues --list` prints findings and exits 0 (for local inspection).
The DB checks are skipped gracefully when a database is not prepared (CI).

`bin/e2e` wipes `storage/test_stamps/*` on every run so E2E uploads never accumulate. It also
removes untracked spec-generated files in `e2e/` (prefixes `e2e-`, `auto-detect-`, `UniqCorte`)
before and after the run; tracked fixtures are never touched.

### storage/stamps vs storage/test_stamps

`storage/stamps/` holds real development/production uploads.
`storage/test_stamps/` holds only RSpec/E2E throwaway uploads — `bin/e2e` and
`spec/rails_helper.rb`'s `after(:suite)` both wipe it unconditionally, and it's
always safe to lose. `ArquivoVersion::STORAGE_BASE` picks the directory via
`Rails.env.test?`.

**Historical note (Sep 2026):** these used to be the same directory. `bin/e2e`'s
`rm -rf storage/stamps/*` — needed so E2E runs never accumulate test uploads —
also silently destroyed real development uploads on every run. The `Arquivo`
rows survived (only the *test* database gets truncated), so the DB kept
saying `status: processed` while the files backing those previews were
gone — the bug looked like "previews aren't rendering," not "files got
deleted." Splitting the directories by environment fixes this by
construction; it can't recur.

### Development backups

`storage/development.sqlite3` and `storage/stamps/` are real, unversioned data
(`.gitignore`'d — no other backup exists). Snapshot before anything risky: a
new destructive script, a bulk delete you're not sure about, testing a
migration by hand.

```bash
bin/dev-backup              # snapshot now (storage/backups/<timestamp>/)
bin/dev-backup my-label     # snapshot tagged "<timestamp>-my-label"
bin/dev-restore --list      # see available snapshots
bin/dev-restore --latest    # restore the most recent one (asks to confirm)
bin/dev-restore <name>      # restore a specific one
```

`bin/dev-restore` refuses to run while `bin/rails server` is listening on
:3000 (stop it first) and asks for confirmation before overwriting. Keeps
the last 10 snapshots; older ones are pruned automatically on each
`bin/dev-backup`.

## Workflow: feature branches + CI guard

```bash
git checkout main
git pull
git checkout -b fix/what-was-done   # e.g. fix/per-color-measurements, add/png-export
```

1. **Changes** — make the code changes.
2. **Server check** — start the Rails server, exercise the feature in the browser, watch `log/development.log` for errors. Fix and re-check until the log is clean.
3. **Browser console** — open DevTools, interact with the new UI, check for console errors. Fix and re-check.
4. **Unit tests** — write tests for new public methods, add regression tests for fixed bugs. Run `bin/rspec` and fix the code until it passes.
5. **E2E tests** — write Playwright tests covering every new use case and UI interaction (buttons, fields, drag-and-drop, etc.). Don't break existing tests.
6. **Final check** — back to the Rails server: test again, re-check `log/development.log` and the browser console. Fix if needed.
7. **Final adjustments** — address whatever the final check surfaced.
8. **Commit** — `git add -A && git commit -m "descriptive message (WHAT + WHY)"`
9. **Push** — `git push -u origin fix/what-was-done`
10. **GitHub PR** — open a Pull Request.
11. **CI** — runs automatically (RSpec + RuboCop + Brakeman + residue check + full E2E via `bin/e2e`).
12. **Merge** — through the GitHub UI, only if CI is green.
13. **Cleanup** — delete the remote branch.

**What an agent may do on its own:** create branches, commit, push, and open
or update PRs (steps 1–10). **Merging (step 12) is always done by a human.**
Never merge, force-push to `main`, or delete branches you didn't create.

⚠️ **Branch protection is not enabled** (GitHub Free + private repo). The
discipline is manual: never merge with red CI.

Before every push, run the **Pre-commit** command from the Commands section.

### Checklist: new controller action

When adding a new action to `ArquivosController` (or any controller with a `before_action`):

1. **Add the action to the `before_action`'s `only:` list** (forgetting it = `NoMethodError` on `nil`)
2. **Write an E2E test** that navigates to the page and performs the action (not just one that checks the route responds)
3. **Run `bin/rails routes`** to confirm the route exists before testing
4. **Run the pre-commit checks** before pushing

### Every new feature needs tests

- **E2E test** for every user flow (open page, interact, see result)
- **RSpec test** for business logic, services, models
- **Regression**: every bug fix comes with a test that reproduces the bug
- **JSON endpoint**: test with `page.evaluate(fetch(...))` in E2E
- **Stimulus controller**: test real interaction (click, input, submit) in E2E
- **Controller action**: test that it responds and persists the expected state
- **Modal/dialog**: test open, fill, submit, **close (Cancel)**, and check the post-redirect result. Also check positioning (centered in the viewport) via `getBoundingClientRect()`
- **Range slider (click-to-edit)**: E2E test must verify: (1) click display → editor appears (hidden class removed), (2) edit value + Enter/blur → display and hidden input updated, (3) editor hidden again after commit
- **Tipo corte**: E2E tests must cover both positive (section appears on corte files with both radio buttons, default `corte_estampa`) and negative (section absent on arte files)
- **Minimum coverage**: before merge, `bin/rspec && bash bin/e2e` must pass 100%

## Architecture

Monolithic Rails 8.1, SQLite3, Hotwire, SolidQueue, ImageMagick.

```
storage/stamps/:uuid/v<N>/original/   # test env: storage/test_stamps/…
storage/stamps/:uuid/v<N>/preview/
```

(`ArquivoVersion#storage_dir`; `Stamp` was renamed to `Arquivo` in `312d326`,
but the storage directory and the `.stamp-card` CSS class kept the old name.)

Key files:
- `app/controllers/arquivos_controller.rb` — upload, preview, versions, DXF organization, CRUD
- `app/services/file_validator.rb` — format/colorspace detection via `identify -ping`
- `app/jobs/arquivo_processing_job.rb` — preview generation, spot channel detection, DXF layers
- `app/models/arquivo.rb` — `SUPPORTED_EXTENSIONS`, lookup by `uuid`
- `app/models/file_category.rb` — category definitions (extensions, preview, spot_detection)

## ImageMagick gotchas (multi-frame TIFFs)

Every `identify -format` string **must** end with `\n` or multi-frame files concatenate output:

```ruby
# WRONG — multi-frame returns "TIFFTIFF"
`identify -format '%m' file.tif`
# RIGHT
`identify -format '%m\\n' file.tif`
```

Every `convert` / `identify -verbose` input path **must** append `[0]` to process only the first frame, or ImageMagick will create `output-0.png`, `output-1.png` instead of `output.png`:

```ruby
Shellwords.escape(input) + "[0]"
```

Always use `2>/dev/null` (not `2>&1`) — ImageMagick stderr is noisy.

## Preview generation

`ArquivoProcessingJob#process_image` selects the strategy based on extension, spots + colorspace (checked in this order):

| Case | Method | Tool |
|------|--------|------|
| DXF | `generate_preview_dxf` | `bin/generate-dxf-preview.js` (outputs `preview.svg`, not PNG) |
| TIFF, spot | `generate_preview_utif` | UTIF.js via `bin/generate-preview.js` |
| CMYK | `generate_preview_cmyk` | ImageMagick (`-profile USWebCoatedSWOP.icc -profile sRGB.icc`) |
| RGB (or PSD/EPS spot) | `generate_preview_rgb` | ImageMagick convert (resize + `-define png:color-type=6`) |

PSD/EPS files with spots use ImageMagick (not UTIF.js, which only handles TIFF). PSD/EPS
CMYK without spots also uses the ICC convert path from the table above.

Spot detection uses `exiftool -s3 -AlphaChannelsNames` (faster and more reliable than `identify -verbose`). Channels named `Transparency` are ignored — only real spot names count. Controlled by `FileCategory.spot_detection_enabled?` per category.

## RGB no-spot preview

Simple ImageMagick resize with `-define png:color-type=6` to force RGBA output:

```ruby
convert input.tif[0] -resize 1200x1200> -define png:color-type=6 output.png
```

The `>` after dimensions means "shrink only" — images smaller than 1200px are
not upscaled. `-define png:color-type=6` forces truecolor+alpha PNG (avoids
palette optimization that breaks pixel-validity checks).

## CMYK no-spot preview

Uses two explicit ICC profiles — source and destination — which ImageMagick
interprets as a colorspace conversion:

```ruby
convert input.tif[0] -profile USWebCoatedSWOP.icc -profile sRGB.icc -define png:color-type=6 output.png
```

`USWebCoatedSWOP.icc` (557KB, "U.S. Web Coated (SWOP) v2") was extracted from
the reference test files. The two `-profile` flags (source then destination)
tell ImageMagick to convert between them, producing correct sRGB output.

The `system()` call uses the array form (`system("convert", arg1, arg2, ...)`)
to avoid shell injection and keep Brakeman's Command Injection check clean.

## UTIF.js known bugs (RGB spot)

UTIF.js `toRGBA8()` only handles `smpls==3` (RGB) and `smpls==4` (RGBA) for
RGB photometric interpretation (intp==2). Files with extra channels
(spots/alpha) have `smpls>=5` and neither branch is entered, returning an
all-zero buffer (fully transparent image).

The fix is in `bin/generate-preview.js`: after `toRGBA8()`, if `spp > 4`,
copy the first 3 raw samples as RGB and set alpha=255, ignoring extra
channels. This affects RGB+spot TIFFs (e.g. 02.tif has 5 samples:
R,G,B,alpha,Spot_1 → we use R,G,B only).

## System dependencies

- `exiftool` — spot channel detection (`sudo apt install exiftool` or `libimage-exiftool-perl`)
- UTIF.js + pngjs — Node.js packages for TIFF→PNG with spot channel support
- ICC profiles in `config/icc/` — `USWebCoatedSWOP.icc`, `sRGB.icc` (+3 printer profiles + XCMYK 2017.icc unused by code)

## Nested forms gotcha (<form> inside <dialog> breaks the parent form)

A `<form>` nested inside another `<form>` **automatically closes the outer form**
in the rendered DOM, even when the HTML source looks right. Submit buttons and
fields end up orphaned — clicking the button "does nothing".

```html
<!-- WRONG — <form> inside <dialog> inside <form> breaks the outer form -->
<form action="/movimentos">
  <div data-controller="client-select">
    <input name="client_id">
    <dialog>
      <form action="/clients">…</form>   <!-- ← closes the /movimentos form here -->
    </dialog>
  </div>
  <input type="submit">  <!-- ← ends up outside any form -->
</form>

<!-- RIGHT — dialog outside the main form, controller wraps both -->
<div data-controller="client-select">
  <form action="/movimentos">
    <input name="client_id">
  </form>
  <dialog>
    <!-- no <form> — uses fetch via Stimulus -->
    <div data-form-action="/clients">…</div>
  </dialog>
  <input type="submit">  <!-- ← inside the /movimentos form -->
</div>
```

**How to detect it:**
- RSpec request specs (`post /materiais, params: {...}`) **don't catch it** — they send HTTP directly, no DOM.
- `form.submit()` via JS also bypasses it.
- Only E2E with a real click (`page.click('input[type="submit"]')`) finds it.
- Check with `page.evaluate(() => document.querySelector('input[type="submit"]').form)` — if it's `null`, the form is broken.

## Turbo Stream gotcha (targets must always be in the DOM)

If an element is the target of `turbo_stream.replace` / `update` / `append`,
render its container (with the `id`) **unconditionally** and hide it with CSS
or an inner condition. Wrapping the container in `<% if %>` makes the stream
a silent no-op whenever the condition was false at page load: no error in the
log or the console, the UI just never updates.

```erb
<%# WRONG — #size-selection-section missing → update_modelo's stream does nothing %>
<% if @arquivo.tamanho&.arquivo&.organize_error.present? %>
  <%= render "size_selection", arquivo: @arquivo %>
<% end %>

<%# RIGHT — always rendered; the partial hides itself until client + modelo exist %>
<%= render "size_selection", arquivo: @arquivo %>
```

Regression history: `019535b` gated Size Selection like the WRONG example, so
picking a client + modelo on an arte stopped showing the size (fixed in #75).
Test it with E2E: trigger the action, then assert the target became visible
*without* a reload.

## Stimulus gotchas (data-action event target)

When a method is called via `data-action="click->controller#method"`, `event.target` is the
element that was clicked (the button), NOT the element the controller lives on. Guard clauses
checking `e.target` against the controller element or a target element will **reject**
direct button clicks:

```javascript
// WRONG — Cancel button click sets e.target = button, not dialog
close(e) {
  if (e && e.target !== this.dialogTarget) return  // Cancel blocked!
  this.dialogTarget.close()
}

// RIGHT — separate backdrop handler from action handler
connect() {
  this.boundClose = this.backdropClose.bind(this)
}
open() {
  this.dialogTarget.showModal()
  this.dialogTarget.addEventListener("click", this.boundClose)
}
backdropClose(e) {
  if (e.target !== this.dialogTarget) return
  this.close()
}
close() {
  this.dialogTarget.close()
  this.dialogTarget.removeEventListener("click", this.boundClose)
}
```

## Guard: never run bin/e2e with the wrong RAILS_ENV

`bin/e2e` truncates the database to guarantee a clean state. Run with
`RAILS_ENV=development`, it would destroy all development data. The script
has a guard clause at the top that aborts if `RAILS_ENV != "test"`.

⚠️ Never run `bin/e2e` with `RAILS_ENV=development`. The script already forces
test, but an earlier `export RAILS_ENV=development` in the shell can override it.

## bin/e2e stops the dev server

The E2E server needs port 3000, so step 1 of `bin/e2e` stops **whatever is
listening on :3000** — normally your development server — with SIGTERM, then
SIGKILL if the port is still busy after 5s. It prints the PID and command it
stopped. Nothing else is touched.

Restart the dev server after the run, in a **separate** command:
`nohup bin/rails server -p 3000 &>/dev/null &`, then poll `curl -s localhost:3000/up`.

**Historical note (Sep 2026):** step 1 used to be `pkill -f "puma"` /
`pkill -f "rails server"`. `pkill -f` matches the full command line of every
process, so it also killed any shell whose command contained those words —
including the one that launched `bin/e2e` (silent exit 144). The same applies
to any `pkill -f` you run yourself: never put its pattern in the same command
line. Prefer stopping by port (`lsof -t -iTCP:3000 -sTCP:LISTEN`).

If a run is interrupted (killed shell, Ctrl-C), check for orphans before the
next run — a leftover `node e2e/*.spec.js` + Chromium keeps hitting the new
server, creating and deleting records mid-run and producing dozens of unrelated
failures: `ps -eo pid,args | grep -E "node e2e|chrom|puma" | grep -v grep`.

## db/seeds.rb is empty on purpose

There is no seed data. `GrupoMaterial`, `CorMaterial` and `Client` are all
managed through the app itself — Materiais page "+ Register new" dialogs
(`create_grupo`/`create_cor`) and `/clients` — so nothing needs to pre-exist
before the app can be used. `CorMaterial` names are capped to
`CorMaterial::COLOR_HEX`'s known set via the "Register New Color" dialog
(so every color always has a real swatch, never the `#CCCCCC` fallback);
`GrupoMaterial` and `Client` names are freeform.

Historical note (Sep 2026): db/seeds.rb used to create demo Clients
("Fagner", "Lipe") plus a fixed list of GrupoMaterial/CorMaterial names.
E2E specs hardcoded those names — removing the seed meant giving
`e2e/{clients,modelos,materiais,movimentos,pedidos}.spec.js` their own
`ensureGrupo`/`ensureCor`/`ensureClient`-style setup instead, so each test
provisions what it needs through the app's own endpoints rather than
assuming global fixtures.

## Key constraints

- Form upload needs `html: { enctype: "multipart/form-data", data: { turbo: false } }`
- Arquivo routes use `uuid` (`Arquivo.find_by!(uuid:)`), not integer id
- Supported extensions in `FileValidator::EXTENSION_TO_FORMAT` and `Arquivo::SUPPORTED_EXTENSIONS` (= `FileCategory.extensions`)
- CI coverage (`.github/workflows/ci.yml`): parallel jobs for brakeman +
  bundler-audit, importmap audit, `bin/check-residues`, rubocop, rspec, and e2e.
  The e2e job runs `bash bin/e2e` — the same entry point as local runs.
- `bin/e2e`'s `E2E_SPECS` array is the single list of E2E specs. A new
  `e2e/*.spec.js` must be added there; the script aborts if any spec file is
  unlisted (before Sep 2026 CI ran only `arquivos.spec.js` and
  `moldes.spec.js` ran nowhere).
- The former `e2e/arquivos.spec.js` is split into `arquivos-*.spec.js` and
  `pages-*.spec.js` (contiguous chunks, original order). They share one test
  DB, truncated once per `bin/e2e` run, and some reuse earlier files' data —
  keep their order in `E2E_SPECS`. Shared harness: `e2e/support/runner.js`
  (`runSpec`), fixture paths: `e2e/support/fixtures.js`.
- System dependencies: `imagemagick`, `exiftool` packages required
