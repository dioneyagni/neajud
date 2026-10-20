# Prévias e processamento de imagem

Preview strategies, ImageMagick/UTIF gotchas and how their tests must check pixels. Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

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

### E2E preview tests

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

### Preventing false positives (image tests)

Tests that only check "does an image load at the URL" miss bugs where
the image is all-transparent or wrong colorspace. Every image conversion
test must validate **pixel content**, not just file existence.
