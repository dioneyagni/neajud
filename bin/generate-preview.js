const UTIF = require("utif");
const fs = require("fs");
const path = require("path");
const { PNG } = require("pngjs");

const inputPath = process.argv[2];
const outputPath = process.argv[3];

if (!inputPath || !outputPath) {
  process.stderr.write("Usage: generate-preview.js <input.tif> <output.png>\n");
  process.exit(1);
}

if (!fs.existsSync(inputPath)) {
  process.stderr.write(`Input file not found: ${inputPath}\n`);
  process.exit(1);
}

try {
  const buf = fs.readFileSync(inputPath);
  const ifds = UTIF.decode(buf);
  UTIF.decodeImage(buf, ifds[0]);
  const img = ifds[0];
  const rgba = UTIF.toRGBA8(img);

  // UTIF.js toRGBA8 only handles up to 4 samples per pixel for RGB.
  // With extra channels (spots/alpha > 4 samples) it returns all zeros.
  // Check photometric interpretation: 2=RGB, 5=CMYK
  const intp = img.t262 ? img.t262[0] : 2;
  const spp = img.t258 ? img.t258.length : 0;

  if (intp === 2 && spp > 4) {
    // RGB + extra channels: toRGBA8 returns all zeros for spp>4.
    // Copy first 3 raw samples as R,G,B and set alpha=255.
    const area = img.width * img.height;
    if (img.data && img.data.length >= area * spp) {
      for (let i = 0; i < area; i++) {
        const qi = i * 4;
        const si = i * spp;
        rgba[qi] = img.data[si];
        rgba[qi + 1] = img.data[si + 1];
        rgba[qi + 2] = img.data[si + 2];
        rgba[qi + 3] = 255;
      }
    }
  }

  if (intp === 5 && spp > 4) {
    // CMYK + extra channels: toRGBA8 uses extra channel as alpha (all-zero
    // if it's a spot channel). Force alpha=255 to show the CMYK content.
    const area = img.width * img.height;
    if (rgba && rgba.length === area * 4) {
      for (let i = 0; i < area; i++) {
        rgba[i * 4 + 3] = 255;
      }
    }
  }

  const png = new PNG({ width: img.width, height: img.height });
  png.data = Buffer.from(rgba);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, PNG.sync.write(png));
  process.exit(0);
} catch (err) {
  process.stderr.write(`Preview generation failed: ${err.message}\n`);
  process.exit(1);
}
