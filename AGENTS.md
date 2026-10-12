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

## Pedido by arte, grade by number (Etapa 1.2, 3/3)

Decided 05/10/2026, in three parts; done 07/10/2026 (Fase 1 complete):

- `pedidos.tipo` (`Pedido::TIPOS`: calcado; DTF and tecido in Fase 2) — one
  type per pedido.
- An item is an **arte** (`itens_pedido.arte_id`); `arquivo_id` is the file it
  was added from, still what the pieces below start from until part 2 reads
  them from the arte. Its grade is by **individual size**
  (`Arte#tamanhos_do_pedido`, decided 05/10/2026: the numbers the molde's
  **organized DXF** serve — saved with the grade type, else deduced from the
  size names like the Mold Organization form; without an organized corte,
  the product's whole grade; the molde's stretch doesn't enter; no molde →
  one `_total`), listed first; "+ 23" / "+ 35" add the product's next numbers
  (`Arte#grade_completa_do_pedido`, decided 05/10/2026), and
  `adicionar_item` / `atualizar_item` refuse sizes outside it. In the
  add-to-order modal the grade is a responsive table
  (`grade_por_numero_controller.js`: number over quantity, side by side under
  600px).
- Part 2: where each number comes from and the pendências — see "Pedido
  items are made of the arte's parts".
- Part 3 in three PRs (decided 06/10/2026, layout studied in a Design
  canvas): **3a** the pedido page — two columns, each item a **matrix**
  (`_item_matriz`: a column per number of the product's grade, rows "Pares"
  and one per part with the DXF size ✓ / "sem arquivo"; columns outside the
  DXF's numbers rendered `hidden`, "+ 28" shows them — `grade_matriz_controller.js`;
  a CSS grid that flows by column on wide screens, by row under 600px), and a
  side panel (`_painel`: totals, Confirmar, the pendências with "Enviar
  arquivo" / "Trazer de outra arte", one per part × DXF size). Saving a grade
  or (un)checking a part morph-refreshes the page. **3b** the factory's
  Corte page (`/pedidos/:uuid/corte`, linked from the panel): one line per
  part × DXF size with its drawing (`/tamanhos/:id/preview`, the PNG made with
  the size's DXF, path rebuilt from version + position), the pieces and the
  DXF; "Baixar os DXF (.zip)" (`baixar_corte`, `baixar_producao`) zips every
  size (`ZipDeArquivos`, the rubyzip wrapper; `DxfDoTamanho` extracts a
  size's DXF for both downloads). Pieces = pairs × the molde part's
  `pecas_por_par` (default 2), half right / half left when `espelhada`
  (needs an even number); parts "não corta" are left out (decided
  06/10/2026). Both are edited per part on the molde page (they live in
  `ResolucaoDoItem::Parte#config`). **3c** the printer's Impressão page
  (`/pedidos/:uuid/impressao`, `ImpressaoPedidoService`): per arte, one line
  per file to print (part, DXF size, side) in pieces, "não corta" parts
  included, what is missing as a line; "Baixar as artes (.zip)"
  (`baixar_impressao`) is written to disk (`ZipDeArquivos.gravar`, stored,
  in `tmp/zips/`, cleaned after an hour by `ZipsTemporarios`) — artes go up
  to 1 GB. **Sides** (`arquivos.lado`, `LadoNaArte`: direito / esquerdo):
  a mirrored part may have a file per side; a file without side serves both
  until one with a side arrives in that size, then the other side is a
  pendência `:sem_lado` ("Enviar arquivo DIR"; decided 07/10/2026). Read
  from the name as its own piece, "DIR" / "ESQ" or spelled out
  (`NomeDoArquivo`), chosen in the upload's conference or on the arte page
  (`definir_lado`); in the full name ("…_Lateral_29-30_ESQ") and in "the
  same arte uploaded again" (the other side is never a repeat).
- Added from the gallery card or from the pedido page (molde → referência →
  arte, `pedido_adicionar_controller.js` + `GET /pedidos/artes_para_adicionar`,
  the same `add-to-order` modal with `pedido_uuid`).
- Pedidos from before (grade by the corte's size name) went to the trash in
  the migration, `grade_antiga: true` — read only even restored
  (`Pedido#editavel?`, `recusar_pedido_excluido`).
- E2E: `e2e/pedido-por-arte.spec.js`.

## Production stages and expected metragem (Etapa 2.2)

Decided 07/10/2026, in three PRs (docs/plano.md has the full rules): stages
per pedido type in `config/etapas_producao.yml` (calçado: Impressão ∥ Corte →
Estamparia → Conferência, every dependency locks), a granular baixa with the
measure next to each download, warned against an expected value that comes
from the files themselves. Done (1/3 to 4/4):

- **Arte**: `ArquivoVersion#metros_por_peca(largura_mm)` — the file's
  rectangle (pixels ÷ DPI) on the paper's width, its width across the roll —
  a calçado arte **never turns** (`girar:` is for DTF later); plain
  arithmetic, nothing stored. The paper's width is the dono's parameter
  (`Empresa#largura_papel_mm`, `/parametros`, with the warning band
  `tolerancia_abaixo_pct` / `tolerancia_acima_pct`).
- **DXF**: `bin/encaixe-dxf.js` fits copies of one size's outer contour on a
  roll (the DXF's **vertical axis runs along the roll**) on a 2 mm grid —
  about 70% of the fabric, between the pieces' area and their bounding
  boxes. The turn is the corte's "Giro no encaixe" (`arquivos.giro`,
  `GiroNoEncaixe`, set on the corte page, decided 08/10/2026): `nenhum`,
  `180` or `90` (0°/90°/180°/270°), **no default** — whoever uploads the corte
  marks it (it isn't always the same; some TNS/BT laterals go with the long
  side along the roll); until then nothing is computed and the card shows
  "giro não marcado". Changing it redoes the sizes.
  `--svg out.svg` draws the fit to check it by eye. The length is the
  average reach of the strips used (a leftover edge no piece reaches is not
  length). After changing the fit itself: `REFAZER=1 bin/rails
  producao:metros_por_peca`. `EncaixeDoTamanho` stores the result per width in
  `tamanhos.metros_por_peca` (`{ "1400" => 0.0183 }`); `MetrosPorPecaJob`
  computes it after `PreparacaoTamanhosJob` (redoing the size) and when a
  material of a new width is created (`MateriaPrima#largura_mm` reads "1.25 m",
  "140 cm"…). Existing sizes: `bin/rails producao:metros_por_peca`. Specs
  inject `FakeEncaixe`.
- The Corte page's lines are per **material** too (each roll is its own cut);
  `Linha#metros_esperados` there and on the Impressão page.
- **Stages and baixas (2/3)**: `EtapasProducao` reads
  `config/etapas_producao.yml` and raises on a wrong value (medida,
  esperado, linhas, niveis, trava). `LinhasDeProducao` gives each stage's
  lines with **stable keys made of uuids** — Impressão lines (also
  Estamparia's and Conferência's) `item/part/size/file/side` with the
  `corte_chave` they wait for (nil for a part "não corta"); Corte lines
  `part/size/material`. `RegistrarBaixaService` takes a line, a referência
  (the item's uuid) or the whole pedido — only open lines whose locked
  stages are done — sums their expected and answers `:aviso` outside the
  dono's band until `confirmar`, then saves `BaixaProducao` with
  `fora_da_faixa`. Only a **confirmed** pedido takes baixas; the endpoint is
  `POST /pedidos/:uuid/baixas` (JSON, action `atualizar_producao`, given by a
  migration to the existing Admin and Produção funções). Pages: the
  Impressão and Corte pages, plus `/pedidos/:uuid/etapas/:etapa` for
  Estamparia and Conferência; `_etapas_nav`, `_etapa_andamento`,
  `_situacao_baixa`, `_baixa` (Stimulus `baixa`).
- **The cycle (3/3)**: `Pedido::STATUS` rascunho (→ enviado, a client's
  draft waiting for the factory, Etapa 2.8 5/5) → confirmado →
  **em_producao** (`iniciar_producao!` on the first baixa) → **entregue**
  (`EntregarPedidoService`, `POST /pedidos/:uuid/entregar`, Stimulus
  `entrega`: never locked — open stages come back as an aviso, "Entregar
  assim mesmo" delivers; `entregue_em`/`entregue_por`). `Pedido#em_producao?`
  (confirmado or em_producao) is what takes baixas; a delivered pedido is
  read only. `DesfazerBaixaService` (`DELETE /pedidos/:uuid/baixas/:uuid`)
  keeps the baixa struck through in the stage's history
  (`_historico_baixas`), refuses while a stage locked on it used those lines,
  and takes the pedido back to confirmado when the last one goes.
  `AndamentoDoPedido` gives each stage's lines done/total for the panel and
  the list (filtered by `?status=`).
- **Reposição (4/4, decided 08-09/10/2026)**: a stage with `reposicao: true`
  (the Conferência) and fewer pieces than expected always sends them to a
  sub-pedido. `ContagemDaConferencia`: a short count (one line or a group)
  answers `:contar` with its lines — the `baixa` controller shows each
  line's count and **Impressão / Corte** checkboxes (checked; the conferente
  unchecks what doesn't need redoing) — and is saved with
  `baixas_producao.contagens`. `AcumularReposicaoService` keeps one **open
  reposição** per pedido (`Pedido#reposicao_em_aberto`: `reposicao_de`,
  status rascunho, out of production) and adds each line short as an
  `ItemReposicao` — file, part, DXF size, side, material, `corta`,
  `refazer_impressao`/`refazer_corte`, **pieces** (not pairs); the same line
  again adds pieces. `LiberarReposicaoService` confirms it when the
  Conferência's last line is done, or by "Gerar reposição" (`POST
  /pedidos/:uuid/gerar_reposicao`); a later shortage opens another.
  `baixa.reposicao` points at it. A line not redone skips that stage
  (`LinhasDeProducao::Linha#dispensa`; no Corte line without
  `refazer_corte`).
  `ImpressaoPedidoService`/`ProducaoPedidoService` build a reposição's lines
  from those items (`pecas_fixas`), so it goes through every stage again
  with the same pages; its own short Conferência makes another one. The
  original's delivery warns while a reposição isn't delivered.

## Stock and materials (Etapa 2.3)

Decided 09/10/2026, kept by hand for now: stock in **linear meters**
(`metros` helper). `MateriaPrima#tipo` is tecido, papel or filme, with
`preco_metro` (the sale price; a movement's `valor` is the cost, per meter).
A movement without client is the **empresa's own stock** — the form marks
it ("Owner: Empresa", `MovimentoEstoque#da_empresa`), so a forgotten client
never turns into the empresa's by accident. `SaldosDeEstoque` splits each
material's balance by owner for the Materials page (type and price edited
there, `PATCH /materiais/:uuid`). The default paper (`Empresa#papel_padrao`,
a papel) gives `Empresa#largura_papel_efetiva_mm` for the artes' meters per
piece, else the typed `largura_papel_mm`. Automatic consumption at
confirmation, the adjustment by the real metragem, "aguardando material"
and the dublagem come later (docs/plano.md, Etapa 2.3).

## Price and cost per pair (Etapa 2.4, calçado)

Decided 09/10/2026: calçado is charged **per pair**, at the molde's price
for each number — `FaixaDePreco` (table `faixas_de_preco`): bands of the
produto's grade, never overlapping, may go past the molde's stretch
(`Molde#preco_do_par`). Edited on the molde page (`FaixasDePrecoController`,
`/moldes/:uuid/faixas`; catalogo: editar + action `ver_valores`); removing a
band is physical on purpose. Confirming writes each number's price into
`itens_pedido_grade.preco_par` (`Pedido#gravar_precos!`, also copied into the
pedidos a split makes); a number without price — or an arte without molde —
is the `:sem_preco` pendência (link "abrir molde"). The molde is read from
the item's **file** (`item.arquivo.molde`), not `arte.principal`, which skips
a trashed file.

The cost per pair is always estimated now (`CustoPorPar`, on
`ResolucaoDoItem`): each checked part's file × its pieces per pair (a side's
file half) × meters per piece × `Empresa#custo_impressao_metro`, plus pieces
cut × `custo_corte_peca` (Parâmetros); `incompleto` when a file is missing
or has no meters. `CustoPorPar.da_arte` builds an unsaved item to show it on
the arte page before any pedido. `ValoresDoPedido` gives price, cost and
margin per number and in total. A cost marked "*" lists what it misses per
part and reason (`CustoPorPar::Custo#faltas`, `faltas_do_custo` helper,
`pedidos/_faltas_do_custo`). Both blocks render only for
`pode_acao?(:ver_valores)`; a reposição has no values. E2E:
`e2e/precos-do-molde.spec.js`; specs that confirm a pedido price their molde
(`precificarMolde` in `e2e/support/catalogo.js`, `create(:molde, preco: 10)`,
`create(:item_pedido, :com_preco)`).

## Pedido items are made of the arte's parts

Adding an arte to a pedido stores one `ItemPedidoPeca` per part of its molde
(e.g. lateral + língua of a tênis), from `MoldeComposicaoService` — the
molde's own parts (`molde_pecas`), each with a file of **that same arte**
(Etapa 1.2, 3/3: never another arte of the molde). A part is `incluida`
(goes to production) or `excluida` (unchecked; the pedido goes without it).

Where each ordered number comes from is `ResolucaoDoItem` (part 2, decided
05/10/2026 — the pedido always reads the arte): per part × number, the size of
the part's organized DXF that serves it (`Tamanho#atende_rotulo?`) and the
arte's production file of that size (`tamanho_id`, else the size read from
its name) — or the part's **piloto** as a sample (only the piloto's size
asked, no production file of it) — or a pendência:

| Pendência | Meaning | Settled by |
|---|---|---|
| `:sem_corte` | no organized DXF of the part serves the number | organizing / linking the DXF |
| `:sem_arquivo` | the DXF serves it, the arte has no file of that size | "Enviar arquivo" (into the arte, part + size filled, back to the pedido) or "Trazer de outra arte" (`/arquivos/:uuid?trazer=1`) |

A file added to the arte settles the pendência in every draft that uses it.
The **parts** themselves follow too (09/10/2026): they were a photo of the
moment the arte was added, so a draft kept a "Sem peça" row (the file, its
part unknown then) next to an empty Cabedal. `ItemPedido#recompor_pecas!`
rebuilds them from `MoldeComposicaoService`, matching rows by peça (an
unchecked part stays unchecked, its uuid kept); `RecomporRascunhos` runs it
on the drafts when a file's part, size, molde or arte changes (`Arquivo`
callbacks) or the molde gains or loses a part (`MoldePeca`). Confirmed
pedidos keep their parts. Existing drafts: `bin/rails pedidos:recompor_rascunhos`.
Confirming is blocked by those pendências of checked parts, an item with total
0, an arte without client (confirming splits the pedido by its artes'
clients) and the item's file in the trash; a grade at total 0 is refused
outright. All blockers come from `PedidoBloqueiosService`
(`Pedido#bloqueios_confirmacao`), which feeds the server guard, the pending
box on the pedido page and the list badge. `Pedido#pecas_para_produzir`
(`ProducaoPedidoService`, built on `ResolucaoDoItem`: lines per part × DXF
size, in pieces, without "não corta" parts) is the **only** place
production reads from.

A draft created for an arte without client has no client: it adopts one
(`Pedido#adotar_cliente_das_artes!`, from `Arquivo`'s `after_update_commit` on
`client_id`) once every arte of it has the same client. An arte without client
gets its molde's client when the molde is chosen (`Arquivo#herdar_cliente_do_molde`).

The old "Escolher arte" / "Enviar arte" per pending piece
(`VincularArteService`, `ArteCandidatasService`) was removed in Etapa 1.2
(3/3, parte 2); the arte page still shows its "Histórico de vínculos".

- E2E coverage: `e2e/pedidos-pecas.spec.js`, `e2e/pedido-por-arte.spec.js`.

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

## Visibility: who sees which records (Etapa 2.8)

Decided 10/10/2026: the same screens for everyone; `Visibilidade` is the
**single place** that says, per model, which rows a person sees — the team
everything, a cliente final (a `Vinculo` with `client_id`; `User#cliente`)
only its client's (`DO_CLIENTE` paths; `COMUNS` for everyone; `DA_EQUIPE`
none). A model without a rule raises. Between empresas nothing is filtered:
each empresa is its own instance.

- **Every query goes through it:** `visiveis(Pedido).ativos…`,
  `visiveis(Arquivo).por_uuid!(…)` (another client's uuid → 404), in
  controllers, views and helpers (`helper_method`). Services that query get
  the visible scope injected (`SaldosDeEstoque.call(visiveis(MovimentoEstoque))`,
  `AgrupamentoDoUpload.call(…, candidatas: visiveis(Arquivo))`). An `.or(…)`
  branch must be visible too (`x.or(visiveis(Arquivo).where(…))`), and an
  association from a visible record to many others (`peca.moldes`) is not
  filtered — intersect it with the visible ids.
- **The guard** (`ControleDeVisibilidade`): outside production an action
  that finished (2xx/3xx) without calling `visiveis` raises, naming itself.
  Actions that read no client records declare `nao_le_registros only: …`.
- **The sweep** (`spec/requests/visibilidade_vazamento_spec.rb`): two
  clients' data, the other's marked "VAZOU"; signed in as a cliente final with
  every level, every GET route — with the other's uuids in the path and the
  query — must never show the mark. New routes are swept automatically.
- **Client access (2/5, decided 10/10/2026):** a função is the team's or
  **para clientes** (`funcoes.para_cliente`, fixed at creation; default
  "Cliente final": every área "ver", no lixeira). A vínculo with `client_id`
  takes only a função para clientes and the team's never one
  (`Vinculo#tipo_da_funcao`); neither a função para clientes nor a client's
  extras may have `Autorizacao::AREAS_DA_EQUIPE` / `ACOES_DA_EQUIPE`
  (lixeira, baixar/atualizar produção, gerenciar usuários, ver valores) —
  `Autorizacao.erros_para_cliente`. Created and listed on the client's page
  ("Acesso ao sistema", `clients/_acesso_ao_sistema`, needs
  `gerenciar_usuarios`) through `UsuariosController` with
  `usuario[client_uuid]`; its actions come back to that page. `/usuarios`
  lists only the team (`User.da_equipe`). A client in the trash closes its
  people's access (`User.com_acesso`, used by the session cookie and the
  cable). A cliente final lands on Pedidos (sign-in and password change);
  the header shows the client's name.
- **Open/closed by kind (3a, decided 10/10/2026):** `TiposParaCliente` lists
  six kinds — pedidos, moldes, estoque (open by default); original, cortes,
  valores (closed). The dono's default grid is `Empresa#visibilidade_cliente`
  (`/visibilidade`, `VisibilidadePadraoController`); a client's exceptions are
  `Client#visibilidade` (its page, `clients/_visibilidade`, "gerenciar
  usuários"). Record kinds are applied **inside `Visibilidade`**
  (`TIPO_DO_MODELO`; cortes closed leaves only artes), so every `visiveis`
  query follows them; capabilities go through helpers that are the team's
  rule for the team: `aberto_ao_cliente?(:x)` (always true for the team),
  `pode_baixar_original?` (`exige_baixar_original`), `pode_ver_precos?`
  (price only — cost and margin stay `pode_acao?(:ver_valores)`), and
  `exige_aberto :cortes` for a page of a kind (404). The artes' previews and
  versions are never a kind (the client approves them). The sweep also signs
  in a client with every kind closed and looks for his own records' uuids.
- **Live updates per client (3b, decided 11/10/2026):** every page
  subscribes through `AoVivoChannel` with the helpers `canal_dos_cartoes` /
  `canal_do_registro(record)` — never `turbo_stream_from`, whose names Turbo
  signs for its own channel, which checks only the signature (a signed name is
  valid forever, for anyone holding it). `CanaisAoVivo` names the streams by
  uuid (`cartoes:equipe`, `cartoes:<client uuid>`, `arquivo:<uuid>`,
  `pedido:<uuid>` — Turbo's default was `gid://…/Arquivo/232`, the integer id
  in the page), signs them with its own verifier and answers `permitido?` on
  every subscription: the team's cards for the team, a client's for its people,
  a page's while `Visibilidade` shows its record. A card goes to the team and
  to each client whose `Visibilidade` shows the file (`dos_cartoes_de`; a
  corte reaches the clients of its moldes while their cortes are open);
  refreshes go through `CanaisAoVivo.recarregar(record)`. Card DOM ids are
  `arquivo_<uuid>` (`id_do_cartao`). The sweep checks every stream a page
  subscribes; E2E: `e2e/canais-ao-vivo.spec.js` listens to the client's
  WebSocket frames.
- **The client answers in the system (4a, decided 12/10/2026):** for a
  função para clientes, `aprovar_arte` means answering a request (the default
  "Cliente final" has it): on the arte's page, while it is `:aguardando`,
  `RespostaDoClienteController` (`exige_cliente_final`) — **Approve** the
  version he picks of each file (`AprovarNoSistemaService`, canal `sistema`,
  "No sistema"; the photo is his choice) or **Ask for changes** with a note
  (`PedirAlteracaoService` → `AlteracaoArte`). Sending and registering stay
  the team's (`exige_equipe`), whatever his grid says.
- **The client uploads his artes (4b, decided 12/10/2026):** a client's
  função or extras stop at `Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE` — artes
  up to editar, the rest only ver (`erros_para_cliente`; the grid offers no
  more; the default "Cliente final" has artes: editar) — so no client
  registers clients, moldes, the common peças or stock. **Every uuid
  assignment goes through `Visibilidade`** (`AtribuiPorUuid` reads
  `Current.user`; nobody signed in = the team's view): another client's
  molde, client or tamanho is a 404. His uploads are his client's
  (`arquivo_do_upload`; an empty arte from the grouping can take a file —
  `artes_que_recebem`), never a DXF. Versions, the version in use, the client
  and the cortes stay the team's (`exige_equipe`; views use
  `equipe_edita_arquivo?`). The write sweep
  (`spec/requests/visibilidade_escrita_spec.rb`) sends every
  POST/PATCH/PUT/DELETE route as client A with B's uuids and checks nothing
  of B changed and nothing of A points at B; new routes are swept
  automatically. E2E: `e2e/cliente-envia.spec.js`.
- **The client's drafts (5/5, decided 12/10/2026):** a client's grid goes up
  to pedidos: editar (the default "Cliente final" has it). He builds a draft
  of his artes and **sends it to the factory** — `Pedido` status `enviado`
  ("aguardando a fábrica", between rascunho and confirmado;
  `Pedido::ANTES_DA_CONFIRMACAO`, `confirmavel?`, scope `nao_confirmados`,
  which `RecomporRascunhos` follows). Pendências never stop sending; on the
  panel his own (quantity 0, a file or side missing) keep their actions and
  the factory's (`PedidoBloqueiosService::DA_FABRICA`) show as "em análise".
  Sent, only the team changes it (`Pedido#editavel?(cliente_final:)`, the
  `recusar_pedido_travado` guard — which also stopped a confirmed pedido's
  grade from changing); he may take it back ("Retirar o envio") until it is
  confirmed. `EnviosPedidoController` (`enviar` / `retirar` for the client,
  `devolver` with a required note for the team) moves the status through
  `EnvioDoPedido` and writes an `EventoPedido` (the pedido's "Histórico").
  Confirming is the team's (`exige_equipe`), from rascunho or enviado. Notices
  stay in the system: the team's header counts the pedidos `enviado`
  (`aguardando_fabrica_count`, links to the filter), the client's Pedidos
  lists the drafts returned with their note on top
  (`Pedido#devolucao_pendente`). E2E: `e2e/cliente-rascunho.spec.js`.

## Art approval (Etapa 0.5, 4/4)

The client's approval of an arte is a **record, never a gate**: production and
confirming a pedido never wait for it (docs/plano.md, "Aprovação de arte").

- `AprovacaoArte` (table `aprovacoes_arte`): one approval of **one version**
  (`arquivo_version`), registered by a user (action `aprovar_arte`) with the
  channel the client used (`CANAIS`; "outro" needs `canal_detalhe`), the date,
  notes and an optional attachment. Cortes are never approved. Cancelled by
  mistake → `cancelar!` (kept in the history, struck through).
- **The client's own answer (Etapa 2.8, 4a):** two more states, both only
  after the request in force — `:alteracao_pedida` (an `AlteracaoArte`: the
  note shows on the arte's page and the badge; the team uses "Send for
  approval again") and `:aprovada_em_outra_versao` (he approved versions not
  in use: `_aprovacao_em_outra_versao` lists them with "Usar esta versão";
  once every one is in use the photo matches and the arte is `:aprovada`).
  The team's form never offers canal `sistema` (`AprovacaoArte::CANAL_SISTEMA`).
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
- **Per arte since Etapa 1.2 (2/3, part 2)** — see "An arte is an envelope
  of files": one request and one approval cover all the arte's files.
- **Attachment** (`AnexoDeAprovacao`): PNG/JPEG/PDF by **first bytes** (no
  ImageMagick/Ghostscript in the request), ≤ 20 MB, stored at
  `<STORAGE_BASE>/<arquivo uuid>/aprovacoes/<aprovação uuid>.<ext>` — the path
  is rebuilt from uuids + a fixed extension, never read from the column;
  always served as a download (`disposition: "attachment"`).
- Sent from the arte page ("Client approval" → "Send for approval");
  registered from there or from a pedido (badge + "Registrar aprovação" on each
  item, only while waiting — the approval is the arte's); `voltar_para` goes through `url_from`, so it
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

## Grade type of a corte (Etapa 1.2, 1/3)

A corte has a `tipo_grade` (`GradeDoCorte::TIPOS`: par, impar, pmg, furada)
and each `Tamanho` keeps its label in `nome` (what the arte's full name and
the pedido show, e.g. "29-30", "P") plus `numeros`, the individual sizes it
serves (strings, like `Molde#grade`).

- **Deduction:** while a corte has no type, the Mold Organization form is
  prefilled by `GradeDoCorte.deduzir` (`grade_proposta` helper). One number
  per size is the **last** of the pair ("24, 26…" → Par 23-24…; "35, 37…" →
  Ímpar 34-35…); written ranges stay; "Size N" deduces nothing. The DXF
  detection takes the numbers from the range in the filename ("35 AO 43").
- **Saving:** `organize` reads every row first (`TamanhoReplacementService`
  with `tipo:` → `GradeDoCorte.ler`, which raises `Invalido` naming the value
  and the expected shape); one bad row refuses the whole save, nothing
  written. Tamanhos are updated **in place by position** — uuid, preview,
  extracted DXF and linked artes stay; only rows past the new list go.
- **Coverage** (`CoberturaDaGrade`) is a **warning, never a block** (decided
  01/10/2026): missing / repeated numbers of `Molde#grade`, shown on the corte
  page (linked moldes) and on the molde page's parts.
- ⚠️ Pedido grades (`itens_pedido_grade.tamanho_nome`) are keyed by the
  tamanho's name: relabeling an old corte ("24" → "23-24") leaves draft pedidos
  pointing at the old name. Fine for the sample data; Etapa 1.2 (3/3) rebuilds
  the pedido on individual sizes.
- E2E: `e2e/arquivos-tipo-grade.spec.js`.

## An arte is an envelope of files (Etapa 1.2, 2/3)

Decided 02/10/2026: **one arte per molde + referência + nome, one file per
part × size**. `Arte` (table `artes`) is the envelope; each file stays an
`Arquivo` with `arte_id` — versions, processing, preview, the automatic size
search and (until part 2) the client approval stay per file.

- **The arte's fields are the same in every file** (`MembroDeArte::CAMPOS_DA_ARTE`:
  client, molde, modelo, referência, nome). `after_update_commit` copies a
  change to the other files (`compartilhar_com_a_arte!`), which then drop a
  size of the old molde and queue their own search. ⚠️ Anything that writes
  these fields with `update_columns` must call `compartilhar_com_a_arte!`
  itself (`ajustar_referencia_e_nome!` does). Part (`peca_id`) and size
  (`tamanho_id`) stay per file.
- Every new non-corte `Arquivo` gets an arte of its own (`before_validation
  on: :create` — before_create ran after the belongs_to autosave, so the arte
  was never saved). Cortes have none.
- **Gallery:** `principais_das_artes` keeps one file per arte (its first) —
  one card, with `resumo_da_arte` ("2 files · Lateral 29-30, 31-32"). Any
  file's broadcast redraws that card. Batch delete trashes the whole arte.
- **Page:** `_arte_arquivos` lists `Arte#arquivos_por_parte`, each file with
  its thumbnail (`miniatura_do_arquivo`, lazy), with `ArteArquivosController`
  (`acrescentar`, `trazer`, `separar`; artes: editar). `trazer` brings the
  **marked** artes into this one (decided 05/10/2026: from the P's page mark
  the M and the G) — preview cards with a text filter (`trazer-artes`
  Stimulus controller), all checked with `JuntarArtesService.erro` before any
  moves. `JuntarArtesService` moves every file (trashed too) and refuses
  moving one to another molde or client; candidates are `artes_para_trazer`.
  `mesma_arte_em_outro_envelope` suggests, with its preview, an arte with
  the same molde, referência and nome.
- ⚠️ Rails 8 draws routes lazily outside eager_load, and a Solid Queue worker
  is its own process: two jobs rendering the card broadcast at once right
  after boot raced the drawing — one failed with `undefined method
  'arquivo_path'` and its file stayed "failed" (development too).
  `config/initializers/solid_queue.rb` draws them on worker start
  (`SolidQueue.on_worker_start`). Specs that need a preview assert
  `data-status="processed"` so a failed processing can't pass unnoticed.
- **Size from the file name:** `NomeDoArquivo` reads it (`tamanho`: "29-30",
  "P"; measures dropped from the name) into `tamanho_rotulo` at upload;
  `TamanhoAutoAssignService` tries it before the outline matcher when exactly
  one size of the file's part's cortes serves it (`Tamanho#atende_rotulo?`).
- **Client approval is the arte's** (part 2, decided 02/10/2026): `Aprovavel`
  is on `Arte`; `Arquivo` delegates `estado_aprovacao` & co. A request or an
  approval (`VersaoDeArte`) has `arte_id` and photographs `arquivo_version_ids`
  (the version in use of each active file) on create. Only the latest valid
  one counts: valid while every photographed file still in the arte keeps that
  version (and at least one is still there). A new version → "not sent" with
  "changed after the last approval" (`alterado_depois_da_aprovacao?` names the
  file); a file added later → still approved, marked "after the approval"
  (`depois_da_aprovacao?`). Joining artes brings the history along.
  `arquivo_id`/`arquivo_version_id` stay: the file whose page it came from
  (the attachment path uses its uuid). The gallery card shows a compact badge
  (`selo_aprovacao(arte, compacto: true)`).
- ⚠️ Read the arte's requests/approvals with a query (`validas.first`), not
  the loaded list: a new Arte starts with its lists loaded (empty), so a
  request created right after was invisible to it.
- **Piloto** (part 2b, decided 05/10/2026, `PapelNaArte`): `arquivos.papel`
  is `producao` (default) or `piloto` — one piloto per part of an arte
  (validated), the editable heavy master. It is in the approval's photo (a
  new version of it undoes the approval); production files of its part made
  before its newest version (v2 on) are `anterior_ao_piloto?` ("before the
  current piloto", a warning). It is never "the same arte uploaded again" of a
  production file (`artes_com_mesmo_nome` skips it). `ArteArquivosController`
  `tornar_piloto` (optional `junto_de`: the other arte joins first — the
  repeated-arte offer) / `voltar_para_producao`. For 3/3: production uses
  `producao`; the piloto only covers a sample (an arte asked only in the
  piloto's size with no production file for it).
- **Grouping at upload** (part 3, decided 05/10/2026): choosing files makes
  `upload_controller.js` POST their names and weights to
  `/arquivos/agrupamento` (`AgrupamentoDoUpload`: key = referência + nome
  from `NomeDoArquivo`, which also reads the part and drops "NEW"/"Copia";
  cortes alone). When something groups (`conferir`), the file list becomes the
  conference (`controllers/conferencia_upload.js`, a plain module): part,
  size, ★ piloto (suggested: PSD/AI/CDR, or ≥ 3× the median weight of the
  part), separate, join groups, add to an existing arte (suggested, never
  chosen). Sending: `POST /artes` makes each group's empty arte, then each
  file goes to `POST /arquivos` with `arquivo[arte_uuid|peca_uuid|tamanho_rotulo|papel]`
  (`Arte#novo_arquivo` copies the arte's fields; a DXF never joins an arte).
- One card per arte: it lists its files (`data-arte-arquivos`) and keeps
  polling while any of them is queued (`data-arte-em-fila`,
  `dados_da_arte_no_card`). A spec whose files must group by name writes them
  outside the repo (an `e2e-` prefix would be read as part of the name) —
  `e2e/upload-agrupamento.spec.js`.
- Pedidos still point at a file until Etapa 1.2 (3/3).
- E2E: `e2e/artes-arquivos.spec.js`.

## Kind of work, numbers and the coleção geral (Etapa 2.5a)

Decided 12/10/2026: an arte says what kind of work it is — `Arte#tipo`
(`TipoDaArte::TIPOS`: `calcado`, everything until then; `dtf`, `corrida`,
`cor_lisa`, the works without corte). A file is still an `Arquivo` of
category `artes`: upload, previews, versions, approval and grouping don't
change.

- **Chosen in the upload** (the gallery's "Kind of work", each group's in the
  conference — `upload_controller.js` / `conferencia_upload.js`): `POST
  /artes` takes `tipo`, a file sent alone takes `arquivo[tipo]`
  (`Arte.novo_do_tipo`); a DXF is always a corte. Changed on the arte page
  (`TiposDaArteController#update`, `Arte#trocar_tipo!`) while no pedido uses
  it and it has no molde — a work without corte takes no molde (validated in
  `MembroDeArte`), and its page hides molde, referência and the corte's size.
  Artes of different kinds are never joined (`JuntarArtesService`).
- **Numbers** (`Sequencia.proximo!`, table `sequencias`, one row per kind): a
  DTF or a corrida takes the next number when it gets the kind — `codigo`
  `DTF-863` / `CR-4114`, unique per kind, never reused (a new kind = a new
  number, a separated file = a new arte and number). Each empresa starts at 1;
  old hand-made numbers stay in the upload's file name. The cor lisa's comes
  with its color family (2.5b). The full name of a work without corte starts
  with it: `DTF-863_Arcoverde_P`; the card shows it; the gallery filters by
  kind (`?tipo=`).
- **The coleção geral** (`Arte#no_catalogo`, "Entra no catálogo", a work
  without corte only; a cor lisa is born in it; marking is the team's —
  `exige_equipe`): every cliente final reads it. `Visibilidade::COLECAO_GERAL`
  adds it to `escopo(…, colecao_geral: true)`; `visiveis` passes it **only on
  GET/HEAD** — a write sees the client's own records, so no client changes
  another's work (an action that must read it in a write asks
  `visiveis(Model, colecao_geral: true)`). Live cards and pages follow
  (`CanaisAoVivo`; `Arquivo#redesenhar_cartao!` removes a card from the
  galleries that stop seeing it). On a work he only reads, a cliente final
  gets no controls, no client field and no answer to an approval
  (`do_proprio_cliente?`, used by `pode_editar_arquivo?`). Both sweeps carry a
  B work in the coleção geral.
- Outside the catálogo the client is required: for now a warning on its page
  ("Without client"); the pedido blocks it when DTF and corrida get theirs.
- **Not in pedidos yet**: only calçado artes go into a pedido (`adicionar_item`
  refuses, the card hides "Pedido") until Etapas 2.6 / 2.7.
- E2E: `e2e/tipo-da-arte.spec.js`.

## Official catalog (Etapa 1.1, 3/5)

Produto (with its grade of individual sizes) and Modelo (the category, with
an abbreviation) are the **official Neajud list**, the same in every
company: `config/catalogo_oficial.yml`, with fixed uuids.

- **Loading:** `CatalogoOficial.sincronizar!` (`bin/rails catalogo:sincronizar`)
  runs after every `db:prepare` (so on deploy and `bin/setup`) and in `bin/e2e`
  after the truncate. Safe to repeat: matched by uuid, updated in place; what
  left the file goes to the trash (`changed_by: "catalogo_oficial"`), comes
  back if listed again. A record with the same name but not in the list (a
  dev sample) is adopted — it takes the official uuid.
- **Read only for the company:** `/modelos` lists them by produto; no
  create/edit/destroy routes, and they aren't restorable from `/lixeira`.
  To add one, edit the YAML in a PR.
- **Molde:** chooses a stretch of its produto's grade (`tamanho_inicial`,
  `tamanho_final`, validated; `Molde#grade` lists it) and has its **own parts**
  (`molde_pecas`, added/removed on the molde page, each "corta / não corta").
  Categories have no pieces: nothing is copied from them.
- ⚠️ **A modelo is shared by every client**, so anything that falls back to
  "cortes of the same modelo" must stay inside the client:
  `Arquivo.cortes_do_molde` and `MoldMatchService` only take cortes of the
  molde's / arte's client (an arte picked another client's corte and sizes
  when the fallback didn't).
- **A molde's cortes come from the molde, never from "the category":** the
  arte's Size Selection (`/pecas/for_cascade` and `/tamanhos/for_cascade`,
  called with `molde_uuid`) lists `Arquivo.cortes_do_molde` like the automatic
  search and the pedido. Filtering by category + client listed nothing once a
  molde moved to the official "Tenis" while its cortes kept the old category,
  and could list another molde's cortes (fixed 01/10/2026).
- E2E: `e2e/support/catalogo.js` (`modeloOficial`, `adicionarPartes`); specs
  pick an official modelo instead of registering one — use a different one
  per spec when cortes could meet in the fallback.

## Molde code (Etapa 1.1, 4/5)

A molde is named `NNN-ABR` + optional suffix ("002-TNS Furado"):

- `numero`: per client, all categories together, **never reused** (the max
  includes trashed moldes; unique index `client_id, numero`). The client is
  fixed once created (validation + the edit dialog hides it).
- The abbreviation is the modelo's, so changing the modelo turns 002-TNS into
  002-JGG; `sufixo` is free text. `nome` **stores the assembled name**
  (`Molde#montar_nome`, before validation) for search and sorting — never
  assign it directly. When the official list changes an abbreviation,
  `CatalogoOficial` calls `Molde#atualizar_nome!` on that modelo's moldes.
- A modelo is required on create (the code needs its abbreviation).
- `variacao_de`: a variation of any molde, **also another client's** (it
  follows its own client's numbering). Set only on create; it is born with the
  base's modelo and grade (when not given), its parts (with "corta/não corta")
  and its corte links (`arquivo_moldes`) — a copy, not inheritance (that is
  Fase 5). `version`, `base_id`, `published_at` exist for Fase 5, unused.
- Forms send `molde[sufixo]`, never `molde[nome]`; JSON search results carry
  `nome`, `codigo` and `sufixo` (E2E specs find their molde by `sufixo`).

## Referência, Nome and the full name (Etapa 1.1, 5/5)

An arte (`category: "artes"`) has a `Referencia` (a grouping inside one molde:
"19", "Fuel"; unique per molde ignoring case/accents — `TextoComparavel`) and a
free `nome` ("Bluey Azul"). `NomeDeArte` (concern in `Arquivo`):

- `nome_completo` — computed, never stored: molde code, referência, nome, part,
  size, empty pieces skipped (`001-TNS_19_Bluey Azul_Lateral_29-30`);
  `para_arquivo: true` drops accents and path characters. The arte download
  (`ArquivosController#download`) uses it as the file name.
- **Filled automatically** when the molde is chosen (`update_molde`) or the arte
  is linked from a pedido (`VincularArteService`): `ajustar_referencia_e_nome!`
  drops another molde's referência and reads blanks from the file name
  (`NomeDoArquivo`: leading number = referência, created in the molde when
  missing; parts and sizes left out — "19-BLUEY PTO-LINGUA" → 19, "BLUEY PTO").
  Edited on the arte page (`NomesArteController#update`).
- **Same arte uploaded twice** = same molde, referência, comparable nome and
  **size** (`artes_com_mesmo_nome`; per size until Etapa 1.2 groups sizes into
  one arte): the newer page offers "Make it a new version of that arte" →
  `JuntarArteRepetidaService` copies its file as the original's new version in
  use (`Arquivo#nova_versao!`, shared with `upload_version`) and trashes the
  newer record. Refused when the newer one is already in a pedido.
- Inflection: `referencia/referencias` (without it Rails looked for a table
  `referencia`).

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
  pedido, unlinking a corte from a molde, removing a part from a molde
  (`remover_parte`), and derived data rebuilt by reprocessing (tamanhos, cut
  layers).

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
  killed; pick another port with `E2E_PORT=3002 bash bin/e2e`. Zombies
  (`<defunct>`, exited but not reaped) are ignored: their environ can't be
  read, and taking one for "a non-test process" failed CI after every spec
  passed (PR #133). Step 5 also waits for its own server to free the port.
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
- Each goes only to who may see it, over `AoVivoChannel` (see "Visibility",
  3b): subscribe with `canal_dos_cartoes` / `canal_do_registro`, refresh with
  `CanaisAoVivo.recarregar`, never `turbo_stream_from` / `broadcast_refresh`.

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
  wait for **the files the upload created** — `POST /arquivos` answers JSON
  `{ uuid, arte_uuid }`, `upload_controller.js` keeps them in the form's
  `data-upload-enviados` — polling `processamento.json` until final, so specs
  can keep assuming a processed file. Waiting for a card by file name was
  satisfied by an older namesake (CI 05/10/2026: a processed `01-no_spot.tif`
  while the new `01-no_spot.psd` was still processing).

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
| Produto | `Produto` (official list, `config/catalogo_oficial.yml`) |
| Modelo (categoria, e.g. Jogging [JGG]) | `Modelo` (was `Molde` until Etapa 1.1, 2/5) |
| Molde (the client's form, e.g. 002-TNS Furado) | `Molde` (was `Modelo` until Etapa 1.1, 2/5) — the names swapped in migration `TrocaMoldeModelo` |
| Referência, Nome (group artes: "20 · Bluey Azul") | `Referencia` (per molde) + `Arquivo#nome` — see "Referência, Nome and the full name"; not catalog, not versioned |
| Parte | `Peca` |
| Corte | `Arquivo` with `category: "corte"` (DXF) + its `Tamanho` records |
| Arte | `Arte` (the envelope) + its `Arquivo`s with `category: "artes"`, one per part × size |
| Tamanho | `Tamanho` (today a named cut inside a corte, e.g. "30"; Etapa 1.2 makes sizes individual, with a grade type per corte: Par, Ímpar, P/M/G, Furada) |
| Etiqueta DTF, Estampa corrida, Cor lisa | don't exist yet (Etapas 2.5–2.7); today uploaded as plain artes (samples only — the beta starts with an empty database) |

## Known gaps vs docs/plano.md

Current code that still differs from the plan — don't copy these patterns into new work:

- **Old docs** — the May 2026 docs (product-requirements, domain-models, architecture,
  testing, …) were removed in Sep 2026: superseded by this file and `docs/plano.md`.
  `docs/current-state.md` (Etapa 0.2) is the audit of the current code (26/09/2026).
