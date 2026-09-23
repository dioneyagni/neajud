// Fixture paths shared by the arquivos-*.spec.js files.

const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");

const testImagePath = path.join(__dirname, "..", "test-image.tif");
const testImagesDir = path.join(__dirname, "..", "..", "spec", "fixtures", "files");

// test-image.tif is tracked in git; this only regenerates it if someone deleted it.
// Usage: ensureTestImage() at the top of a spec that uploads testImagePath.
function ensureTestImage() {
  if (fs.existsSync(testImagePath)) return;
  execSync(`convert -size 100x100 xc:red -compress none 'TIFF:${testImagePath}'`);
}

module.exports = { testImagePath, testImagesDir, ensureTestImage };
