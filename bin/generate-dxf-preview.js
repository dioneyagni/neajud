#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const dxf = require("dxf");

if (process.argv.length < 4) {
  console.error("Usage: generate-dxf-preview.js <input.dxf> <output.svg>");
  process.exit(1);
}

const inputPath = path.resolve(process.argv[2]);
const outputPath = path.resolve(process.argv[3]);

if (!fs.existsSync(inputPath)) {
  console.error("Input file not found:", inputPath);
  process.exit(1);
}

const content = fs.readFileSync(inputPath, "latin1");
const parsed = dxf.parseString(content);
const svg = dxf.toSVG(parsed);

// Ensure output directory exists
const outDir = path.dirname(outputPath);
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

fs.writeFileSync(outputPath, svg, "utf-8");
console.log("SVG preview generated:", outputPath);
