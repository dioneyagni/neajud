#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const dxf = require("dxf");

if (process.argv.length < 3) {
  console.error("Usage: detect-tamanhos.js <input.dxf> [filename]");
  process.exit(1);
}

const inputPath = path.resolve(process.argv[2]);
const rawFilename = process.argv[3] || path.basename(inputPath, path.extname(inputPath));
if (!fs.existsSync(inputPath)) {
  console.error("Input file not found:", inputPath);
  process.exit(1);
}

const content = fs.readFileSync(inputPath, "latin1");
const parsed = dxf.parseString(content);
const result = dxf.toPolylines(parsed);

if (!result || !result.polylines || result.polylines.length === 0) {
  console.log(JSON.stringify({ tamanhos: [] }));
  process.exit(0);
}

function dist(a, b) {
  return Math.hypot(b[0] - a[0], b[1] - a[1]);
}

function pointInPolygon(px, py, verts) {
  let inside = false;
  for (let i = 0, j = verts.length - 1; i < verts.length; j = i++) {
    const xi = verts[i][0], yi = verts[i][1];
    const xj = verts[j][0], yj = verts[j][1];
    if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

function polygonCentroid(verts) {
  let cx = 0, cy = 0;
  for (const v of verts) { cx += v[0]; cy += v[1]; }
  return { x: cx / verts.length, y: cy / verts.length };
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

function polygonPerimeter(verts) {
  let perimeter = 0;
  const n = verts.length;
  for (let i = 0; i < n; i++) {
    perimeter += dist(verts[i], verts[(i + 1) % n]);
  }
  return perimeter;
}

function bboxArea(verts) {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const v of verts) {
    if (v[0] < minX) minX = v[0];
    if (v[1] < minY) minY = v[1];
    if (v[0] > maxX) maxX = v[0];
    if (v[1] > maxY) maxY = v[1];
  }
  return (maxX - minX) * (maxY - minY);
}

function lineBbox(lx1, ly1, lx2, ly2) {
  return { minX: Math.min(lx1, lx2), minY: Math.min(ly1, ly2), maxX: Math.max(lx1, lx2), maxY: Math.max(ly1, ly2) };
}

function bboxOverlap(a, b) {
  return a.minX <= b.maxX && a.maxX >= b.minX && a.minY <= b.maxY && a.maxY >= b.minY;
}

function cross(ox, oy, ax, ay, bx, by) {
  return (ax - ox) * (by - oy) - (ay - oy) * (bx - ox);
}

function segmentsIntersect(a1, a2, b1, b2) {
  const c1 = cross(a1[0], a1[1], a2[0], a2[1], b1[0], b1[1]);
  const c2 = cross(a1[0], a1[1], a2[0], a2[1], b2[0], b2[1]);
  const c3 = cross(b1[0], b1[1], b2[0], b2[1], a1[0], a1[1]);
  const c4 = cross(b1[0], b1[1], b2[0], b2[1], a2[0], a2[1]);
  if (c1 === 0 || c2 === 0 || c3 === 0 || c4 === 0) return false;
  return (c1 > 0) !== (c2 > 0) && (c3 > 0) !== (c4 > 0);
}

function polylinesOverlap(a, b) {
  const ba = bboxArea(a);
  const bb = bboxArea(b);
  if (ba <= 0 || bb <= 0) return false;
  const ab = bboxOverlap(
    { minX: Math.min(...a.map(v => v[0])), minY: Math.min(...a.map(v => v[1])),
      maxX: Math.max(...a.map(v => v[0])), maxY: Math.max(...a.map(v => v[1])) },
    { minX: Math.min(...b.map(v => v[0])), minY: Math.min(...b.map(v => v[1])),
      maxX: Math.max(...b.map(v => v[0])), maxY: Math.max(...b.map(v => v[1])) }
  );
  if (!ab) return false;
  for (let i = 0; i < a.length; i++) {
    const ai = a[i], aj = a[(i + 1) % a.length];
    for (let j = 0; j < b.length; j++) {
      const bi = b[j], bj = b[(j + 1) % b.length];
      if (segmentsIntersect(ai, aj, bi, bj)) return true;
    }
  }
  return false;
}

function rgbToHex(r, g, b) {
  return "#" + [r, g, b].map(c => c.toString(16).padStart(2, "0")).join("").toUpperCase();
}

function effectiveColor(rgb) {
  if (rgb[0] === 255 && rgb[1] === 255 && rgb[2] === 255) return [0, 0, 0];
  return rgb;
}

// Find closed polylines with their colors
const closed = [];
for (const pl of result.polylines) {
  const verts = pl.vertices;
  if (verts.length >= 3 && dist(verts[0], verts[verts.length - 1]) < 0.01) {
    const eff = effectiveColor(pl.rgb);
    closed.push({
      vertices: verts,
      color: rgbToHex(eff[0], eff[1], eff[2]),
      area: polygonArea(verts),
      bboxArea: bboxArea(verts),
      centroid: polygonCentroid(verts),
    });
  }
}

closed.sort((a, b) => b.bboxArea - a.bboxArea);

// Outer polylines = those NOT fully contained inside any larger polyline
// (prevents legitimate separate shapes from being excluded when their
// centroid happens to fall inside a neighboring shape's polygon)
const outer = [];
for (const poly of closed) {
  let fullyContained = false;
  for (const other of closed) {
    if (other === poly) continue;
    if (other.bboxArea > poly.bboxArea) {
      const allInside = poly.vertices.every(v => pointInPolygon(v[0], v[1], other.vertices));
      if (allInside) {
        fullyContained = true;
        break;
      }
    }
  }
  if (!fullyContained) {
    outer.push(poly);
  }
}

// Detect overlaps among outer polylines
const overlapping = [];
for (let i = 0; i < outer.length; i++) {
  for (let j = i + 1; j < outer.length; j++) {
    if (polylinesOverlap(outer[i].vertices, outer[j].vertices)) {
      overlapping.push({
        tamanho_a: i,
        tamanho_b: j,
        color_a: outer[i].color,
        color_b: outer[j].color,
      });
    }
  }
}

const insUnits = parsed.header && parsed.header.insUnits;
const toMm = insUnits === 1 ? 25.4 : 1;

function polylineLength(verts) {
  let len = 0;
  for (let i = 0; i < verts.length - 1; i++) len += dist(verts[i], verts[i + 1]);
  return len;
}

function isInsideOuter(verts, outerVerts) {
  for (const v of verts) {
    if (pointInPolygon(v[0], v[1], outerVerts)) return true;
  }
  return false;
}

// Build list of all non-outer polylines (both closed-inner and open)
const outerSet = new Set(outer);
const innerPolylines = [];
for (const pl of result.polylines) {
  const verts = pl.vertices;
  if (verts.length < 2) continue;
  const isClosed = verts.length >= 3 && dist(verts[0], verts[verts.length - 1]) < 0.01;
  const inOuter = isClosed && closed.some(c => c.vertices === verts) && outerSet.has(closed.find(c => c.vertices === verts));
  if (inOuter) continue;
  const length = isClosed ? polygonPerimeter(verts) : polylineLength(verts);
  if (length > 0) innerPolylines.push({ vertices: verts, length, isClosed });
}

function inferSizeNames(filename, count) {
  const patterns = [
    /(\d+)\s*(?:ao|a)\s*(\d+)/i,
    /(\d+)\s*[-–]\s*(\d+)/,
  ];
  for (const pat of patterns) {
    const m = filename.match(pat);
    if (!m) continue;
    const lo = parseInt(m[1], 10);
    const hi = parseInt(m[2], 10);
    if (isNaN(lo) || isNaN(hi) || lo === hi) continue;
    const step = lo % 2 === hi % 2 ? 2 : 1;
    const expectedCount = Math.abs(Math.round((hi - lo) / step)) + 1;
    if (count !== expectedCount) continue;
    const sizes = [];
    if (lo < hi) { for (let s = lo; s <= hi; s += step) sizes.push(String(s)); }
    else { for (let s = lo; s >= hi; s -= step) sizes.push(String(s)); }
    return sizes;
  }
  return null;
}

outer.reverse();

const sizeNames = inferSizeNames(rawFilename, outer.length);

const tamanhos = outer.map((poly, i) => {
  const nome = sizeNames ? sizeNames[i] : `Size ${i + 1}`;
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const v of poly.vertices) {
    if (v[0] < minX) minX = v[0];
    if (v[1] < minY) minY = v[1];
    if (v[0] > maxX) maxX = v[0];
    if (v[1] > maxY) maxY = v[1];
  }

  let innerLinesMm = 0;
  for (const ip of innerPolylines) {
    if (isInsideOuter(ip.vertices, poly.vertices)) {
      innerLinesMm += ip.length;
    }
  }
  innerLinesMm = Math.round(innerLinesMm * toMm * 100) / 100;
  const outerPerim = Math.round(polygonPerimeter(poly.vertices) * toMm * 100) / 100;

  return {
    nome: nome,
    position: i + 1,
    color: poly.color,
    width_mm: Math.round((maxX - minX) * toMm * 100) / 100,
    height_mm: Math.round((maxY - minY) * toMm * 100) / 100,
    area_mm2: Math.round(poly.area * toMm * toMm * 100) / 100,
    perimeter_mm: outerPerim,
    inner_lines_mm: innerLinesMm,
    total_line_mm: outerPerim + innerLinesMm,
  };
});

console.log(JSON.stringify({ count: tamanhos.length, tamanhos, overlaps: overlapping }));
