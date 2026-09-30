# Neajud — AGENTS.md

Where things are documented — read the first three before proposing changes:

| Document | What it covers |
|---|---|
| `AGENTS.md` (this file) | How to work on the code **as it is today**: style, tests, commands, workflow, gotchas |
| `docs/plano.md` | Where the product is going: phases, target domain, rules for agents |
| `docs/contexto-claude-code.md` | Launch order, decisions taken in sessions, topics still to discuss |
| `docs/current-state.md` | Audit of the current code: models, routes, UUIDs, deletes, where processing runs, sublimation-specific vs generic |
| `README.md` | Short overview and quick start |

When this file and `docs/plano.md` disagree, the plan wins for **new** work; the
"Known gaps vs docs/plano.md" list under Key constraints names what the current
code still does differently. The two docs/ files are in Portuguese for now
(translating them is an open decision in `docs/plano.md`).

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
  restart the dev server (:3000) when needed. When there are
  no errors in the console, test e2e, then e2e --headed and check if
  everything goes through. Correct what is necessary and test again.
- An intermittent failure is never "noise". Before calling it unrelated to
  your change: run the suite N times on your branch and N times on `main`,
  compare failure rates, and check request ordering in the failing run's
  `log/e2e/<run>/requests.log` (e.g. a `Started GET` arriving before the
  previous POST's `Completed`).
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
- **Running one spec by hand** (`node e2e/<name>.spec.js` against
  `bin/rails s -e test -p 3001 -P tmp/pids/e2e-server.pid`, see "Dev server
  and E2E server run side by side"): the test server does **not** reload edited JS/CSS
  (Propshaft caches assets outside development). Restart it after changing
  `app/javascript` or stylesheets — otherwise you are testing the old code
  (a mutation check "passed" this way). `bin/e2e` restarts it on every run.
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
bash bin/e2e                  # Playwright E2E (headless) on its own port :3001 — the dev server on :3000 keeps running
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

Each `bin/e2e` run keeps its logs in `log/e2e/<YYYYmmdd-HHMMSS>-<pid>/`
(`log/e2e/latest` → newest; the last 10 runs are kept):

- `requests.log` — this run's slice of `log/test.log`, i.e. the Rails request
  log (`Started …` / `Completed …`). This is the one to read: in the test env
  requests are **not** written to the server's stdout.
- `server.log` — the server process's stdout/stderr (boot, Puma, crashes).

Before each spec the script appends a `=== [HH:MM:SS] spec: <name> ===` marker
to both, so a request can be traced to the spec that made it. The folder is
printed at the end of the run and next to the failed-spec list. In CI it is
uploaded as the `server-log` artifact on failure.

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
8. **Commit** — Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`; release notes are generated from them — `docs/plano.md`), subject + body with WHAT + WHY
9. **Push** — `git push -u origin fix/what-was-done`
10. **GitHub PR** — open a Pull Request.
11. **CI** — runs automatically (RSpec + RuboCop + Brakeman + residue check + full E2E via `bin/e2e`).
12. **Merge** — through the GitHub UI, only if CI is green.
13. **Cleanup** — delete the remote branch.

**What an agent may do on its own:** create branches, commit, push, and open
or update PRs (steps 1–10). **Merging (step 12) is always done by a human.**
Never merge, force-push to `main`, or delete branches you didn't create.

⚠️ **Branch protection is not enabled**: the repo is private (since 26/09/2026) and
GitHub Free doesn't offer branch protection for private repos (needs GitHub Team —
see Etapa 3.5 in `docs/plano.md`). The discipline is manual: never merge with red CI.

Before every push, run the **Pre-commit** command from the Commands section.

### Rules from docs/plano.md

- One stage per PR; big features become chained series (1/N, 2/N).
- At the end of each stage: list changed files, explain what changed, report tests run
  and problems found, then wait for human validation. Merge is always human.
- Every migration that transforms data runs on a copy first (`bin/dev-backup`) and has
  its rollback tested.
- Don'ts:
  - Don't rewrite the app or swap the frontend (no React, Vue or similar).
  - Don't use `default_scope` to hide deleted records.
  - Don't delete records physically (only when anonymizing personal data).
  - Don't process PSD, TIFF, AI, EPS or PDF inside the web request.
  - Don't add dependencies without justifying them in the PR.
  - Don't create abstractions before a second real use exists. This does not contradict
    "wrap third-party libs behind a thin interface" (Dependencies): wrap a library where
    the app calls it, don't build generic layers for our own code "just in case".
- Some of these are still violated by existing code — see "Known gaps" under Key constraints.

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

## Pedido items are made of the molde's pieces

Adding an arte to a pedido stores one `ItemPedidoPeca` per peça of its molde
(e.g. lateral + língua of a tênis). The arte → peça link is
`Arquivo#resolved_peca`: the corte's peça (via tamanho), else the arte's own
`peca_id` (SQL mirror: `Arquivo.sem_peca_resolvida`).

| Estado | Meaning | Production | Confirmar |
|---|---|---|---|
| `incluida` | has arte, checked | yes | allowed |
| `excluida` | has arte, unchecked | the pedido goes without it | allowed |
| `pendente` | no arte yet | no | **blocked** (UI + server) |

Confirming is also blocked by an item with total quantity 0 and by a
checked piece whose arte has no corte (no tamanho chosen); adding or saving a
grade at total 0 is refused outright. All blockers come from
`PedidoBloqueiosService` (`Pedido#bloqueios_confirmacao`), which feeds the
server guard, the pending box on the pedido page and the list badge.

- `MoldeComposicaoService` builds the pieces (molde_pecas, else the modelo's
  pieces, read-only); the added arte always wins its own peça.
- `Pedido#pecas_para_produzir` (`ProducaoPedidoService`) is the **only** place
  production reads from — peça × tamanho over checked pieces.
- A pending piece is completed by choosing an existing arte
  (`ArteCandidatasService`: client's artes without peça → without molde →
  without client) or uploading one (`ArquivoUploadService`); both link via
  `VincularArteService`, which logs to `arquivo_vinculo_logs` ("Histórico de
  vínculos" on the arte page) and fills the same pending peça in every draft
  pedido of the molde. Moving an arte out of another molde requires an
  explicit confirmation, enforced server-side.
- E2E coverage: `e2e/pedidos-pecas.spec.js`.

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

## Security

What exists today (verified against the code, Sep 2026):

- Upload limit 1GB, checked on the **real file size on disk**, never `Content-Length`
  or browser metadata (`ArquivoUploadService`).
- File type identified by **content**, not extension or browser MIME (`FileValidator`,
  `ArquivoUploadService.erro_de_tipo`); DXF/DWG/CAD can't be verified this way.
- Abuse: oversize uploads enqueue `AbuseDetectionJob`, which bans the IP (`Ban`) after
  repeated attempts; `lib/ban_middleware.rb` blocks banned IPs; `Rack::Attack`
  (`config/initializers/rack_attack.rb`) rate-limits.
- Files on disk are named by generated ids/uuids, never by user-typed text (the tamanho
  DXF extract used `tamanho.nome` and allowed path traversal — fixed in #97).
- Brakeman must stay at 0 warnings; an entry in `config/brakeman.ignore` needs a note
  explaining why it is a false positive (#97 found one "false positive" that was real).

Not done yet (targets in `docs/plano.md` "Segurança de arquivos" and Etapa 8.4): running
Ghostscript-based previews (PDF/EPS/AI) isolated with `-dSAFER` and limits, a project
ImageMagick `policy.xml`, disk encryption. The old idea of SQLCipher was dropped in favor
of disk encryption.

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
<%# WRONG — #size-selection-section missing → update_molde's stream does nothing %>
<% if @arquivo.tamanho&.arquivo&.organize_error.present? %>
  <%= render "size_selection", arquivo: @arquivo %>
<% end %>

<%# RIGHT — always rendered; the partial hides itself until client + molde exist %>
<%= render "size_selection", arquivo: @arquivo %>
```

Regression history: `019535b` gated Size Selection like the WRONG example, so
picking a client + molde on an arte stopped showing the size (fixed in #75).
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

## Authentication (Etapa 0.5)

Every page requires a signed-in user (Rails 8 authentication generator:
`Authentication` concern, `Session`, `Current.user`, `bcrypt`). Only
`SessionsController#new/create` and the first-access setup are public.

- **Model:** `User` (the plan's "pessoa"; name chosen in session) +
  `Empresa` (**one per instance** — docs/plano.md Etapa 3.1; `Empresa.atual`)
  + `Vinculo` (user × empresa × **one `Funcao`** + `acessos_extras`). New
  tables get a `uuid` via the `GeraUuid` concern; `users.cloud_user_uuid`
  links to the future Neajud Cloud account (Etapa 7.1).
- **First access:** while there is no user, every page redirects to
  `/configuracao` (`ConfiguracaoInicialService`: empresa + first user as
  `dono`). Once a user exists the screen redirects to sign in — it must never
  reopen (it would let anyone create a second owner).
- **No password reset by email.** On the Usuários page a manager sets a
  **provisional password** (`User#definir_senha_provisoria!`, sets
  `trocar_senha`): until the person picks their own at `/senha/edit`,
  `Authentication#exigir_troca_de_senha` redirects every page there. Anyone
  changes their own password from their name in the header. Email recovery
  comes with the cloud account (Etapa 7.1).
- **Users are deactivated, never deleted** (`User#desativar!`): sign-in is
  refused, sessions end, and `find_session_by_cookie` / the cable connection
  only accept `User.ativos`.
- **Usuários page** (`/usuarios`, action `gerenciar_usuarios`):
  `CadastroDeUsuarioService` saves name, email, função and acessos extras;
  `GestaoDeUsuarios` holds the rules — only a dono manages donos or gives the
  Dono função, nobody gives more than they have, the empresa always keeps an
  active dono, nobody deactivates themselves.
- **Who did it:** controllers pass `**autoria` (`{ changed_by: request.remote_ip,
  user: Current.user }`, `ApplicationController`) to every log and to
  `excluir!`/`restaurar!` (fills `deleted_by_id`/`restored_by_id`). Views show
  `autor_do_log(log)`: the user's name, else the IP of pre-0.5 rows.
- **Action Cable** rejects connections without a session cookie
  (`ApplicationCable::Connection`).
- **Tests:** request specs sign in as a dono automatically
  (`spec/support/autenticacao.rb`, `@usuario_logado`); tag a group
  `sem_login: true` to test signed-out behavior. E2E specs start signed in
  (`e2e/support/sessao.js`, called by `runSpec`); `autenticacao.spec.js` runs
  **first** in `E2E_SPECS` because it needs the empty database to exercise the
  setup screen, and opts out with `runSpec(…, { entrar: false })`.

## Permissions (Etapa 0.5, 2/4)

Decided 27/09/2026: instead of the plan's fixed perfis, the **dono edits a
grid** (`/funcoes`) and creates funções — many workers share one função.

- **Grid:** `Funcao#niveis` = level per área (`Autorizacao::AREAS`: pedidos,
  clientes, artes, catalogo, estoque, lixeira), 0 nenhum · 1 ver · 2 editar
  (create/edit) · 3 excluir; each level includes the lower ones. Lixeira stops
  at 2 = restaurar (`Autorizacao::NIVEL_MAXIMO`). `Funcao#acoes` = special
  actions (`baixar_producao`, `gerenciar_usuarios`, `aprovar_arte`). `Vinculo#acessos_extras`
  (same shape) can only **raise** a user's levels (UI in 3/4).
- **Dono** is a system função (`Funcao.dono`): everything, not editable, never
  deleted. Editing funções is dono-only on purpose (it grants permissions).
- **One entry point:** `Autorizacao` (`user.autorizacao.pode?(:pedidos, :editar)`,
  `pode_acao?`, `dono?`). An unknown área/level/action **raises** — a typo
  must not silently deny or allow.
- **Server:** controllers declare requirements with `exige :area, :nivel, only:`,
  `exige_acao`, `exige_dono` (`ControleDeAcesso`); refused → 403 page "Sem
  permissão" (JSON: `{ ok: false, error: "No permission: needs …" }`). **Every
  new action needs one** — `spec/requests/permissoes_spec.rb` holds one row per
  requirement (403 below it, allowed at it); add yours.
- **Arquivos** belong to Artes, or to Catálogo when they are cortes
  (`Arquivo#area_de_acesso`); the gallery lists only visible categories
  (`Arquivo.categorias_visiveis`); batch delete skips what the user can't delete.
- **Views** hide what the user can't do with `pode?` / `pode_acao?` / `dono?`,
  `pode_editar_arquivo?(arquivo)` and `pedido_editavel?(pedido)`.
- ⚠️ **Partials rendered by broadcast** (`arquivos/_card`, via
  `broadcast_replace_to`) have **no user**: never call `pode?` in them. Their
  controls are hidden by CSS from `<body data-pode-…>` flags in the layout.
- Tests: `entrar_com_funcao(niveis: { "pedidos" => 1 }, acoes: [...])` signs
  in a request spec as a user of such a função.

## Art approval (Etapa 0.5, 4/4)

The client's approval of an arte is a **record, never a gate**: production and
confirming a pedido never wait for it (docs/plano.md, "Aprovação de arte").

- `AprovacaoArte` (table `aprovacoes_arte`): one approval of **one version**
  (`arquivo_version`), registered by a user (action `aprovar_arte`) with the
  channel the client used (`CANAIS`; "outro" needs `canal_detalhe`), the date,
  notes and an optional attachment. Cortes are never approved. Cancelled by
  mistake → `cancelar!` (kept in the history, struck through).
- **Nothing waits until it is sent** (changed before merge, 28/09/2026):
  `SolicitacaoAprovacao` = "Enviar para aprovação" for the version in use.
  `Aprovavel#estado_aprovacao` is `:nao_enviada` (default — no badge, no
  register button anywhere) → `:aguardando` (sent) → `:aprovada`. Registering
  an approval is refused unless it is `:aguardando` (service + controller).
  All of it is per **version in use** (`approved_version`): a new version
  starts over as not sent (`aprovada_versao_anterior?` tells an older one was
  approved). Both records share `VersaoDeArte` (version of that arte, artes
  only) and `Cancelavel` (cancel = kept in the history).
- ⚠️ **Naming:** `approved_version` / `ArquivoVersion#approved` / the
  `approve_version` route mean **"the version in use"**, not client approval.
  The UI says "Usar esta versão" / "Em uso"; keep "Aprovar/Aprovada" for
  `AprovacaoArte` only.
- **Attachment** (`AnexoDeAprovacao`): PNG/JPEG/PDF by **first bytes** (no
  ImageMagick/Ghostscript in the request), ≤ 20 MB, stored at
  `<STORAGE_BASE>/<arquivo uuid>/aprovacoes/<aprovação uuid>.<ext>` — the path
  is rebuilt from uuids + a fixed extension, never read from the column;
  always served as a download (`disposition: "attachment"`).
- Sent from the arte page ("Client approval" → "Send for approval");
  registered from there or from a pedido (badge + "Registrar aprovação" on each
  piece, only while waiting); `voltar_para` goes through `url_from`, so it
  can't redirect to another host.
- Portuguese plurals the app routes on need an inflection
  (`config/initializers/inflections.rb`: materiais, funcoes, aprovacoes,
  solicitacoes) —
  without it `resources :aprovacoes` generated `new_arquivo_aprovaco_path`.

## Public identifiers are uuids (Etapa 1.1, 1/5)

The integer id is the internal key only; nothing that leaves the server
carries it (a guessable sequence would let the future cliente final reach
other clients' records). Every entity includes `GeraUuid` (pure join tables,
`sessions`, the 1:1 `arquivo_image_metadata` and `itens_pedido_grade` — rows
addressed by tamanho name inside their item — don't need one).

- **URLs:** `GeraUuid#to_param` is the uuid, so path helpers build
  `/clients/<uuid>`; controllers look up with `Model.por_uuid!(params[:id])`
  (also on a relation: `@arquivo.arquivo_versions.por_uuid!(…)`). An integer
  id answers 404.
- **JSON:** `id` is the record's uuid (`{ id: c.uuid, name: … }`); a reference
  to another record is `<assoc>_uuid` (`modelo_uuid`).
- **Forms and fetch params:** name them `<assoc>_uuid` (`client_uuid`,
  `molde[modelo_uuid]`, `modelo[peca_uuids][]`), never `<assoc>_id` with a uuid
  inside: Rails casts `"8f3a…"` to the integer 8 and links the wrong record
  silently. Models declare `atribui_por_uuid :client, :modelo`
  (`AtribuiPorUuid`) so `Molde.new(client_uuid: …)` works; blank unlinks, an
  unknown uuid raises `RecordNotFound`. Filters use a subquery:
  `where(modelo: Modelo.where(uuid: params[:modelo_uuid]))`.
- Tests: `spec/requests/uuid_publico_spec.rb` checks pages, JSON endpoints and
  forms; add a row when you add an endpoint.

## Logical deletion (Etapa 0.4)

Nothing a user deletes is physically destroyed. `Arquivo`, `Client`, `Molde`,
`Modelo`, `Peca` and `Pedido` include `Excluivel` (`app/models/concerns/excluivel.rb`):
`excluir!(changed_by:)` / `restaurar!(changed_by:)` set `deleted_at` / `restored_at`
and write an `ExclusaoLog`; `/lixeira` lists them with Restore.

- **No `default_scope`.** A trashed record must keep showing where it is already
  used (a pedido's arte, a molde's client), with `selo_excluido(record)` (the
  "excluído em" badge). So every **listing, picker, search and JSON endpoint**
  must say `.ativos` explicitly — `Client.ativos.order(:name)`,
  `@modelo.pecas.ativos`, `Arquivo.ativos.where(...)`. Lookups by id/uuid for a
  show page stay unscoped. When you add a query that feeds a list or a
  `<select>`, add `.ativos`.
- **Counts on index pages** use `Model.contagem_ativos(as: "x_count")` (Arel),
  not `COUNT(DISTINCT table.id)`, so trashed children aren't counted.
- **New references to trashed records are refused** by `ReferenciaAtiva`
  (`recusa_excluido :client, :molde` on the referencing model). Rows that
  already pointed at the record stay valid. A controller that assigns a
  reference must report the validation error, not raise.
- **No cascade.** Trashing a client leaves its moldes, stock and arquivos as
  they are. `dependent:` options on these models only matter for internal hard
  deletes (tests, future "empty trash").
- **Files stay** in `storage/stamps/<uuid>` for trashed arquivos.
- **Names stay unique across the trash.** `create` actions check the name
  first and answer with `record.aviso_na_lixeira` (restore instead of a duplicate).
- **Trashed pedidos are frozen** (`PedidosController#recusar_pedido_excluido`,
  `Pedido#editavel?`); a draft that uses a trashed arte or corte can't be
  confirmed (`PedidoBloqueiosService` `:arquivo_excluido`).
- Still physical on purpose: removing an item / zeroing a size of a **draft**
  pedido, unlinking a corte from a molde, and derived data rebuilt by
  reprocessing (tamanhos, cut layers, `molde_pecas` sync).

## Guard: never run bin/e2e with the wrong RAILS_ENV

`bin/e2e` truncates the database to guarantee a clean state. Run with
`RAILS_ENV=development`, it would destroy all development data. The script
has a guard clause at the top that aborts if `RAILS_ENV != "test"`.

⚠️ Never run `bin/e2e` with `RAILS_ENV=development`. The script already forces
test, but an earlier `export RAILS_ENV=development` in the shell can override it.

⚠️ Never run `bin/rspec` while `bin/e2e` is running: both use the **same test
database**, and each one's cleanup (RSpec transactions/truncation, `bin/e2e`'s
`db:test:prepare`) breaks the other — you get `StatementTimeout`s and records
vanishing mid-spec, not real failures. Run them one after the other.

## Dev server and E2E server run side by side

- **Development server: port 3000**, development database. Keep it running.
- **E2E test server: port 3001** (`E2E_PORT`, default 3001), test database,
  started and stopped by `bin/e2e`. Specs read the URL from `E2E_BASE_URL`
  (`e2e/support/runner.js`). It writes its PID to `tmp/pids/e2e-server.pid`,
  not the default `tmp/pids/server.pid` the dev server uses — sharing it made
  the second server refuse to boot.
- `bin/e2e` only ever stops a **leftover test server** on the E2E port
  (checked via `RAILS_ENV=test` in `/proc/<pid>/environ`). Anything else on
  that port — a dev server, another app — is refused with a message, never
  killed; pick another port with `E2E_PORT=3002 bash bin/e2e`.
- Running one spec by hand:
  `bin/rails s -e test -p 3001 -P tmp/pids/e2e-server.pid`, then
  `node e2e/<name>.spec.js` (restart that server after editing JS/CSS).
- **Restart the dev server after changing `config/initializers/`, the
  Gemfile or `config/*.yml`** — code reloading doesn't cover them. Example
  (Sep 2026): `inflect.irregular "funcao", "funcoes"` was added while the dev
  server ran; it kept looking for a table `funcaos` and every page returned
  500 until restarted (RSpec and E2E boot fresh, so they didn't catch it).
  Same after **testing a migration's rollback** (`db:rollback` + `db:migrate`)
  with the server up: it can cache the table's columns mid-cycle — creating
  a user failed with "unknown attribute 'trocar_senha'" although the column
  existed.
- Before trusting what `localhost:<port>` shows, check which environment is
  behind it: `tr '\0' '\n' < /proc/$(lsof -t -iTCP:3000 -sTCP:LISTEN)/environ | grep RAILS_ENV`
  (empty = development).

**Historical note (Sep 2026):** both servers used to share port 3000.
`bin/e2e` stopped the dev server and put the test server in its place for
the whole run (minutes per run, several runs in a row), so `localhost:3000`
silently showed test data. No data was lost — only what was being served
changed. Step 1 was also `pkill -f "puma"` / `pkill -f "rails server"`,
which matched every process's full command line and killed any shell whose
command contained those words, including the one that launched `bin/e2e`
(silent exit 144). The same applies to any `pkill -f`/`pgrep -f` you run
yourself: never put its pattern in the same command line. Select processes
by port (`lsof -t -iTCP:<port> -sTCP:LISTEN`) instead.

If a run is interrupted (killed shell, Ctrl-C), check for orphans before the
next run — a leftover `node e2e/*.spec.js` + Chromium keeps hitting the new
server, creating and deleting records mid-run and producing dozens of unrelated
failures: `ps -eo pid,args | grep -E "node e2e|chrom|puma" | grep -v grep`.

## Background processing (Solid Queue + Solid Cable)

Since Etapa 0.3, `ArquivoProcessingJob` is enqueued (`perform_later`) by
`ArquivoUploadService` and `upload_version`; the request only stores the file
and the version starts `pending` → `processing` → `processed`/`failed`.

| Where | Jobs | Cable (live updates) |
|---|---|---|
| Production | Solid Queue inside Puma (`SOLID_QUEUE_IN_PUMA`) | Solid Cable |
| Development | Solid Queue inside Puma (`config/puma.rb` enables it in development) — `bin/rails server` alone processes uploads | Solid Cable |
| E2E server (`bin/e2e`) | Solid Queue inside Puma (`E2E_SOLID_QUEUE=1`) | Solid Cable (`CABLE_ADAPTER=solid_cable`) |
| RSpec | inline (specs assert on the processed result) | test adapter |

Development and test have their own `*_queue.sqlite3` and `*_cable.sqlite3`
(`config/database.yml`); `bin/e2e` recreates the test ones every run.

How the UI learns the result (`Arquivo#broadcast_status_change`, called when a
version's status changes):

- the gallery card is replaced on every change ("Na fila", "Processando");
  cards carry `data-status` and `data-filename`;
- the arquivo page and the pedidos using the arte morph-refresh **only when
  processing ends** — never mid-edit.

**Automatic tamanho search (Etapa 0.6, 1/3):** picking an arte's molde
(`update_molde`) no longer runs `MoldMatchService` in the request (measured up
to 37 s on dev data): `Arquivo#buscar_tamanho_em_fila!` sets
`buscando_tamanho_desde` and enqueues `TamanhoAutoAssignJob`, which always
clears it and `broadcast_refresh`es the arte page (found or not). Meanwhile
Size Selection shows "Procurando tamanho…" with the `processamento`
controller polling `GET /arquivos/:uuid/busca_tamanho.json`; a mark older than
10 minutes counts as over (a dead job never leaves the page waiting).
`TamanhoAutoAssignJob.matcher` is injectable (`FakeMoldMatcher` in specs).

**Preparing a corte's tamanhos (Etapa 0.6, 2/3 + 3/3):** `organize` and
`configure_layers` only save what was chosen and call
`Arquivo#preparar_tamanhos_em_fila!(redetectar:)` → `PreparacaoTamanhosJob`
(re-detects via `DxfOrganizationService.call` after a failed organize, else
`generate_tamanho_previews`). Each size's DXF is extracted once, to
`Tamanho#dxf_extraido_path` (`<version>/tamanho_previews/<position>.dxf`,
next to its preview), and production's download serves that file — extracting
it on the spot only if asked before it is ready or older than the version
(`tmp/tamanho_extracts/` is no longer used). The corte page shows "Preparando
os tamanhos…" polling `GET /arquivos/:uuid/preparacao_tamanhos.json`; same
10-minute expiry (`Arquivo::TAREFA_EM_FILA_EXPIRA`). The organizer is
injectable (`PreparacaoTamanhosJob.organizador`, `FakeOrganizadorDxf`).
Previews feed the automatic tamanho search: an arte linked while its corte is
still preparing falls back to dimensions or to picking the size by hand.

Gotchas found while building it:

- The worker is a **separate process**: the in-process `async` cable adapter
  never reached the browser. Anything that broadcasts from a job needs Solid
  Cable (or another cross-process adapter).
- Broadcast **synchronously** from inside the job (`broadcast_replace_to`,
  `broadcast_refresh`), not `*_later`: queued broadcasts ran out of order and a
  late refresh reset an editor the user had just opened.
- **Reload** before broadcasting: the job's `arquivo` cached its
  `approved_version` as another object, so it still read "processing" and the
  final update never went out (regression spec in
  `spec/models/arquivo_broadcast_status_spec.rb`).
- A broadcast sent while the page is still (re)connecting to the cable is
  **lost** (seen after an upload reload, mostly in `--headed`). Safety net: while
  queued, the card, the arquivo banner and a pedido piece carry the
  `processamento` Stimulus controller, which polls `GET /arquivos/:uuid/processamento`
  every 2s until the state is final (card: swaps itself via turbo-stream; pages:
  reload). The E2E "Without the live connection…" blocks WebSocket to prove it.
- E2E: `uploadFileAndWait` / `submitUploadAndWait` (`e2e/support/upload.js`)
  wait for the newest card of each uploaded file to leave "pending"/"processing"
  (`waitForProcessed`), so specs can keep assuming a processed file.

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
`e2e/{clients,moldes,materiais,movimentos,pedidos}.spec.js` their own
`ensureGrupo`/`ensureCor`/`ensureClient`-style setup instead, so each test
provisions what it needs through the app's own endpoints rather than
assuming global fixtures.

## Key constraints

- Time fields use the `h:mm` mask (e.g. `130` → 1:30, `2430` → 24:30), parsed by
  `ArquivosController#parse_hmm`.

- Form upload needs `html: { enctype: "multipart/form-data", data: { turbo: false } }`
- Every route, JSON and form value uses the `uuid` — see "Public identifiers are uuids"
- Supported extensions in `FileValidator::EXTENSION_TO_FORMAT` and `Arquivo::SUPPORTED_EXTENSIONS` (= `FileCategory.extensions`)
- CI coverage (`.github/workflows/ci.yml`): parallel jobs for brakeman +
  bundler-audit, importmap audit, `bin/check-residues`, rubocop, rspec, and e2e.
  The e2e job runs `bash bin/e2e` — the same entry point as local runs.
- `bin/e2e`'s `E2E_SPECS` array is the single list of E2E specs. A new
  `e2e/*.spec.js` must be added there; the script aborts if any spec file is
  unlisted (before Sep 2026 CI ran only `arquivos.spec.js` and
  `moldes.spec.js` ran nowhere; since Etapa 1.1 (2/5) that file is `modelos.spec.js`).
- The former `e2e/arquivos.spec.js` is split into `arquivos-*.spec.js` and
  `pages-*.spec.js` (contiguous chunks, original order). They share one test
  DB, truncated once per `bin/e2e` run, and some reuse earlier files' data —
  keep their order in `E2E_SPECS`. Shared harness: `e2e/support/runner.js`
  (`runSpec`), fixture paths: `e2e/support/fixtures.js`.
- System dependencies: `imagemagick`, `exiftool` packages required

## Code names vs docs/plano.md names

The plan renames things; until those stages land, the code keeps its names:

| docs/plano.md | Code today |
|---|---|
| Produto | doesn't exist yet (Etapa 1.1, 3/5) |
| Modelo (categoria, e.g. Jogging [JGG]) | `Modelo` (was `Molde` until Etapa 1.1, 2/5) |
| Molde (the client's form, e.g. 002-TNS Furado) | `Molde` (was `Modelo` until Etapa 1.1, 2/5) — the names swapped in migration `TrocaMoldeModelo` |
| Referência, Nome (group artes: "20 · Bluey Azul") | don't exist yet (Etapa 1.1, 5/5); not catalog, not versioned |
| Parte | `Peca` |
| Corte | `Arquivo` with `category: "corte"` (DXF) + its `Tamanho` records |
| Arte | `Arquivo` with `category: "artes"` |
| Tamanho | `Tamanho` (today a named cut inside a corte, e.g. "30"; Etapa 1.2 makes sizes individual, with a grade type per corte: Par, Ímpar, P/M/G, Furada) |
| Etiqueta DTF, Estampa corrida, Cor lisa | don't exist yet (Etapas 2.5–2.7); today uploaded as plain artes (samples only — the beta starts with an empty database) |

## Known gaps vs docs/plano.md

Current code that still differs from the plan — don't copy these patterns into new work:

- **No "cliente final"** — the client's own access (seeing only their pedidos
  and artes) needs every query filtered by client. Target: Etapa 2.8, before
  the beta.
- **Client approval only registered by the team** — "aprovada pelo cliente no
  sistema" needs the cliente final (its own etapa before the beta).
- **Old docs** — the May 2026 docs (product-requirements, domain-models, architecture,
  testing, …) were removed in Sep 2026: superseded by this file and `docs/plano.md`.
  `docs/current-state.md` (Etapa 0.2) is the audit of the current code (26/09/2026).
