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
- Test the Rails server, observe any errors in the console and correct them, shut down and restart the server and all related processes. When there are no errors in the console, test e2e, then e2e --headed and check if everything goes through. Correct what is necessary and test again.

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

Pre-commit: `bin/rspec && bin/rubocop && bin/brakeman --exit-on-warn`

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

## Key constraints

- Form upload needs `html: { enctype: "multipart/form-data", data: { turbo: false } }`
- Stamp routes use `uuid` (`Stamp.find_by!(uuid:)`), not integer id
- Supported extensions in `FileValidator::EXTENSION_TO_FORMAT` and `Stamp::SUPPORTED_EXTENSIONS`
- CI runs brakeman → bundler-audit → importmap audit → rubocop → rspec → e2e
- System dependency: `imagemagick` package required
