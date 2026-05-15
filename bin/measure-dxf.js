#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const dxf = require("dxf");

if (process.argv.length < 3) {
  console.error("Usage: measure-dxf.js <input.dxf>");
  process.exit(1);
}

const inputPath = path.resolve(process.argv[2]);
if (!fs.existsSync(inputPath)) {
  console.error("Input file not found:", inputPath);
  process.exit(1);
}

const content = fs.readFileSync(inputPath, "latin1");
const parsed = dxf.parseString(content);
const result = dxf.toPolylines(parsed);

if (!result || !result.polylines || result.polylines.length === 0) {
  console.log(JSON.stringify([]));
  process.exit(0);
}

const insUnits = parsed.header && parsed.header.insUnits;
const toMm = insUnits === 1 ? 25.4 : 1;

function dist(a, b) {
  return Math.hypot(b[0] - a[0], b[1] - a[1]);
}

function polygonArea(verts) {
  let area = 0;
  const n = verts.length;
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    area += verts[i][0] * verts[j][1];
    area -= verts[j][0] * verts[i][1];
  }
  return Math.abs(area) / 2;
}

function perimeter(verts) {
  let p = 0;
  for (let i = 1; i < verts.length; i++) {
    p += dist(verts[i - 1], verts[i]);
  }
  return p;
}

function rgbToHex(r, g, b) {
  return "#" + [r, g, b].map(c => c.toString(16).padStart(2, "0")).join("").toUpperCase();
}

const groups = {};
for (const pl of result.polylines) {
  const rgb = pl.rgb;
  // Apply white→black conversion to match SVG color attribute
  const effectiveRgb =
    rgb[0] === 255 && rgb[1] === 255 && rgb[2] === 255
      ? [0, 0, 0]
      : rgb;
  const hex = rgbToHex(effectiveRgb[0], effectiveRgb[1], effectiveRgb[2]);
  if (!groups[hex]) {
    groups[hex] = { hex, polylines: [], minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity };
  }
  groups[hex].polylines.push(pl);
  for (const v of pl.vertices) {
    if (v[0] < groups[hex].minX) groups[hex].minX = v[0];
    if (v[1] < groups[hex].minY) groups[hex].minY = v[1];
    if (v[0] > groups[hex].maxX) groups[hex].maxX = v[0];
    if (v[1] > groups[hex].maxY) groups[hex].maxY = v[1];
  }
}

const measurements = Object.values(groups).map(g => {
  let totalPerimeter = 0;
  let totalArea = 0;
  for (const pl of g.polylines) {
    const verts = pl.vertices;
    const isClosed = verts.length >= 3 && dist(verts[0], verts[verts.length - 1]) < 0.01;
    totalPerimeter += perimeter(verts);
    if (isClosed) {
      totalPerimeter += dist(verts[0], verts[verts.length - 1]);
      totalArea += polygonArea(verts);
    }
  }
  const width = (g.maxX - g.minX) * toMm;
  const height = (g.maxY - g.minY) * toMm;
  return {
    color: g.hex,
    width_mm: Math.round(width * 100) / 100,
    height_mm: Math.round(height * 100) / 100,
    perimeter_mm: Math.round(totalPerimeter * toMm * 100) / 100,
    area_mm2: Math.round(totalArea * toMm * toMm * 100) / 100,
  };
});

measurements.sort((a, b) => a.color.localeCompare(b.color));

console.log(JSON.stringify(measurements));
