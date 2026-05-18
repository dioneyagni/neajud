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

- Tests run with a single command: `<project-specific>`.
- Every new function gets a test and test e2e. Bug fixes get a regression test.
- Mock external I/O (API, DB, filesystem) with named fake classes,
  not inline stubs.
- Tests must be F.I.R.S.T: fast, independent, repeatable,
  self-validating, timely.
- Test the Rails server, observe any errors in the console and correct them,
  shut down and restart the server and all related processes. When there are
  no errors in the console, test e2e, then e2e --headed and check if
  everything goes through. Correct what is necessary and test again.

### Job & image processing tests

- `spec/jobs/stamp_processing_job_spec.rb` tests each conversion method
  (`generate_preview_rgb`, `generate_preview_cmyk`, `generate_preview_utif`,
  `detect_spots`, `process_image` routing).
- Each conversion test **must** verify: (1) a valid PNG is produced,
  (2) dimensions match the source, (3) the PNG contains visible pixels
  (decompress IDAT and check non-zero alpha + RGB).
- CMYK spot via UTIF.js is a known limitation — test only file validity,
  not pixel content.
- `detect_spots` tests use real files from `spec/fixtures/files/` to verify
  spot detection accuracy (including `Transparency` filtering).

### E2E tests

- `e2e/stamps.spec.js` covers all 4 preview strategies: RGB no-spot,
  RGB spot, CMYK no-spot, CMYK spot.
- Each preview test **must** verify: (1) status is `processed`,
  (2) colorspace label matches expected, (3) preview image loads (200 OK,
  `image/*` content-type), (4) preview has visible pixels (load into canvas,
  check first 100x100 region for non-zero alpha + RGB).
- CMYK spot is exempt from pixel validation (UTIF.js limitation).
- Stamp card selectors must match by **filename without extension** using
  `page.locator(".stamp-card").filter({ hasText: displayName })` to avoid
  flaky clicks on wrong cards when multiple stamps exist.
- Run 3 times in succession to verify stability.

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
bash bin/e2e                  # Playwright E2E (headless)
bash bin/e2e --headed         # Playwright E2E (visible browser)
```

Pre-commit: `bin/rspec && bin/rubocop && bin/brakeman --no-pager`

## Workflow: feature branches + CI guard

```bash
git checkout main
git pull
git checkout -b fix/o-que-foi-feito   # ex: fix/per-color-measurements, add/png-export
```

1. **Alterações** — faz as mudanças no código
2. **Teste no servidor** — sobe o Rails server, testa a funcionalidade no navegador, observa o `log/development.log` em busca de erros. Corrigir e conferir novamente até o log limpo
3. **Console do navegador** — abre DevTools, interage com a UI nova, verifica se há erros no console. Corrigir e conferir novamente
4. **Testes unitários** — escrever testes para novas funções, adicionar testes de regressão para bugs corrigidos. Rodar `bin/rspec` e corrigir código até passar.
5. **Testes E2E** — escrever testes no Playwright cobrindo todos os novos casos de uso e interações com a interface nova (botões, campos, drag-and-drop, etc). Não quebrar testes existentes.
6. **Verificação final** — volta ao Rails server, testa de novo, confere o `log/development.log` e console do navegador mais uma vez. Corrigir se necessário.
7. **Alterações finais** — ajusta o que apareceu na verificação
8. **Commit** — `git add -A && git commit -m "mensagem descritiva (WHAT + WHY)"`
9. **Push** — `git push -u origin fix/o-que-foi-feito`
10. **PR no GitHub** — abrir Pull Request
11. **CI** — roda automaticamente (RSpec + RuboCop + Brakeman + E2E)
12. **Merge** — pelo GitHub UI se CI estiver verde
13. **Limpeza** — deletar branch remoto

⚠️ **Branch protection não está ativa** (GitHub Free + repo privado). A
disciplina é manual: nunca fazer merge com CI vermelho.

Pre-commit antes de todo push: `bin/rspec && bin/rubocop && bin/brakeman --no-pager`

### Checklist: nova ação no controller

Quando criar uma nova action em `StampsController` (ou qualquer controller com `before_action`):

1. **Adicione a action na lista `only:` do `before_action`** (esquecer isso = `NoMethodError` em `nil`)
2. **Crie um E2E test** que navega até a página e executa a ação (não só testa que a rota responde)
3. **Rode `bin/rails routes`** pra confirmar que a rota existe antes de testar
4. **Execute o pre-commit** antes de push

### Toda nova funcionalidade precisa de teste

- **E2E test** para cada fluxo do usuário (abrir página, interagir, ver resultado)
- **RSpec test** para lógica de negócio, serviços, modelos
- **Regressão**: bug fix sempre acompanhado de teste que reproduz o bug
- **Endpoint JSON**: testar com `page.evaluate(fetch(...))` no E2E
- **Stimulus controller**: testar interação real (clique, input, submit) no E2E
- **Controller action**: testar que responde e persiste o estado esperado
- **Modal/dialog**: testar abrir, preencher, submit, **fechar (Cancel)**, e verificar resultado pós-redirect. Verificar também posicionamento (centrado no viewport) via `getBoundingClientRect()`
- **Cobertura mínima**: antes de merge, `bin/rspec && bash bin/e2e` deve passar 100%

## Architecture

Monolithic Rails 8.1, SQLite3, Hotwire, SolidQueue, ImageMagick.

```
storage/stamps/:uuid/original/
storage/stamps/:uuid/preview/
```

Key files:
- `app/controllers/stamps_controller.rb` — upload, preview, CRUD
- `app/services/file_validator.rb` — format/colorspace detection via `identify -ping`
- `app/jobs/stamp_processing_job.rb` — preview generation, spot channel detection
- `app/models/stamp.rb` — `SUPPORTED_EXTENSIONS`, lookup by `uuid`
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

StampProcessingJob selects strategy based on extension, spots + colorspace:

| Case | Method | Tool |
|------|--------|------|
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

## Dependencies

- `exiftool` — spot channel detection (`sudo apt install exiftool` or `libimage-exiftool-perl`)
- UTIF.js + pngjs — Node.js packages for TIFF→PNG with spot channel support
- ICC profiles in `config/icc/` — `USWebCoatedSWOP.icc`, `sRGB.icc` (+3 printer profiles + XCMYK 2017.icc unused by code)

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

## Key constraints

- Form upload needs `html: { enctype: "multipart/form-data", data: { turbo: false } }`
- Stamp routes use `uuid` (`Stamp.find_by!(uuid:)`), not integer id
- Supported extensions in `FileValidator::EXTENSION_TO_FORMAT` and `Stamp::SUPPORTED_EXTENSIONS`
- CI runs brakeman → bundler-audit → importmap audit → rubocop → rspec → e2e
- System dependencies: `imagemagick`, `exiftool` packages required
