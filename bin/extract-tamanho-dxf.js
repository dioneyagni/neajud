#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const dxf = require("dxf");

if (process.argv.length < 5) {
  console.error("Usage: extract-tamanho-dxf.js <input.dxf> <output.dxf> <position>");
  console.error("  position: 1-based index of the tamanho to extract");
  process.exit(1);
}

const inputPath = path.resolve(process.argv[2]);
const outputPath = path.resolve(process.argv[3]);
const position = parseInt(process.argv[4], 10);

if (!fs.existsSync(inputPath)) { console.error("Input file not found:", inputPath); process.exit(1); }
if (isNaN(position) || position < 1) { console.error("Invalid position:", process.argv[4]); process.exit(1); }

// ── Geometry helpers ──

function dist(a, b) { return Math.hypot(b[0] - a[0], b[1] - a[1]); }
function pointInPolygon(px, py, verts) {
  let inside = false;
  for (let i = 0, j = verts.length - 1; i < verts.length; j = i++) {
    const xi = verts[i][0], yi = verts[i][1], xj = verts[j][0], yj = verts[j][1];
    if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
function polygonCentroid(verts) { let cx = 0, cy = 0; for (const v of verts) { cx += v[0]; cy += v[1]; } return { x: cx / verts.length, y: cy / verts.length }; }
function polygonArea(verts) { let area = 0; for (let i = 0; i < verts.length; i++) { const j = (i + 1) % verts.length; area += verts[i][0] * verts[j][1] - verts[j][0] * verts[i][1]; } return Math.abs(area) / 2; }
function bboxArea(verts) { let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity; for (const v of verts) { if (v[0] < minX) minX = v[0]; if (v[1] < minY) minY = v[1]; if (v[0] > maxX) maxX = v[0]; if (v[1] > maxY) maxY = v[1]; } return (maxX - minX) * (maxY - minY); }
function effectiveColor(rgb) { return (rgb[0] === 255 && rgb[1] === 255 && rgb[2] === 255) ? [0, 0, 0] : rgb; }
function rgbToHex(r, g, b) { return "#" + [r, g, b].map(c => c.toString(16).padStart(2, "0")).join("").toUpperCase(); }
function isInsideOuter(verts, outerVerts) { for (const v of verts) { if (pointInPolygon(v[0], v[1], outerVerts)) return true; } return false; }

function entityBbox(entity) {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  const points = [...(entity.controlPoints || []), ...(entity.fitPoints || []), ...(entity.vertices || [])];
  for (const p of points) {
    if (Array.isArray(p)) { minX = Math.min(minX, p[0]); maxX = Math.max(maxX, p[0]); minY = Math.min(minY, p[1]); maxY = Math.max(maxY, p[1]); }
    else if (p && p.x !== undefined) { minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x); minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y); }
  }
  if (entity.center) { const cx = Array.isArray(entity.center) ? entity.center[0] : entity.center.x; const cy = Array.isArray(entity.center) ? entity.center[1] : entity.center.y; minX = Math.min(minX, cx); maxX = Math.max(maxX, cx); minY = Math.min(minY, cy); maxY = Math.max(maxY, cy); }
  if (entity.radius !== undefined && isFinite(entity.radius)) { minX -= entity.radius; minY -= entity.radius; maxX += entity.radius; maxY += entity.radius; }
  return { minX, minY, maxX, maxY };
}

function blockBbox(blockEntities, blocksByName, depth) {
  if (depth > 10) return { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity };
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const ent of blockEntities) {
    let b;
    if (ent.type === "INSERT" && ent.block) {
      const nested = blocksByName[ent.block];
      b = nested && nested.entities ? blockBbox(nested.entities, blocksByName, depth + 1) : entityBbox(ent);
      const ox = ent.x || 0;
      const oy = ent.y || 0;
      if (isFinite(b.minX) && (ox !== 0 || oy !== 0)) {
        b = { minX: b.minX + ox, minY: b.minY + oy, maxX: b.maxX + ox, maxY: b.maxY + oy };
      }
    } else {
      b = entityBbox(ent);
    }
    if (!isFinite(b.minX)) continue;
    minX = Math.min(minX, b.minX); minY = Math.min(minY, b.minY);
    maxX = Math.max(maxX, b.maxX); maxY = Math.max(maxY, b.maxY);
  }
  return { minX, minY, maxX, maxY };
}

// ── Parse DXF and find target tamanho ──

const content = fs.readFileSync(inputPath, "latin1");
const parsed = dxf.parseString(content);

if (parsed.blocks) {
  const blocksByName = {};
  for (const key of Object.keys(parsed.blocks)) {
    const b = parsed.blocks[key];
    if (b.name) blocksByName[b.name] = b;
  }
  parsed._blocksByName = blocksByName;
}

const result = dxf.toPolylines(parsed);

if (!result || !result.polylines || result.polylines.length === 0) {
  console.error("No polylines found in DXF");
  process.exit(1);
}

const closed = [];
for (const pl of result.polylines) {
  const verts = pl.vertices;
  if (verts.length >= 3 && dist(verts[0], verts[verts.length - 1]) < 0.01) {
    const eff = effectiveColor(pl.rgb);
    closed.push({ vertices: verts, color: rgbToHex(eff[0], eff[1], eff[2]), area: polygonArea(verts), bboxArea: bboxArea(verts), centroid: polygonCentroid(verts) });
  }
}
closed.sort((a, b) => b.bboxArea - a.bboxArea);

const outer = [];
for (const poly of closed) {
  let contained = false;
  for (const other of closed) { if (other === poly) continue; if (other.bboxArea > poly.bboxArea && pointInPolygon(poly.centroid.x, poly.centroid.y, other.vertices)) { contained = true; break; } }
  if (!contained) outer.push(poly);
}

outer.reverse();

const targetIndex = position - 1;
if (targetIndex >= outer.length) { console.error(`Position ${position} out of range (found ${outer.length} sizes)`); process.exit(1); }

const targetOuter = outer[targetIndex];
const targetPolyBbox = {
  minX: Math.min(...targetOuter.vertices.map(v => v[0])) - 0.5,
  minY: Math.min(...targetOuter.vertices.map(v => v[1])) - 0.5,
  maxX: Math.max(...targetOuter.vertices.map(v => v[0])) + 0.5,
  maxY: Math.max(...targetOuter.vertices.map(v => v[1])) + 0.5,
};

const outerSet = new Set(outer);
const innerPolylines = [];
for (const pl of result.polylines) {
  const verts = pl.vertices;
  if (verts.length < 2) continue;
  const isClosed = verts.length >= 3 && dist(verts[0], verts[verts.length - 1]) < 0.01;
  const inOuter = isClosed && closed.some(c => c.vertices === verts) && outerSet.has(closed.find(c => c.vertices === verts));
  if (inOuter) continue;
  innerPolylines.push({ vertices: verts, isClosed });
}
const targetInner = innerPolylines.filter(ip => isInsideOuter(ip.vertices, targetOuter.vertices));
const allTargetBboxes = [targetPolyBbox, ...targetInner.map(ip => ({
  minX: Math.min(...ip.vertices.map(v => v[0])) - 0.5, minY: Math.min(...ip.vertices.map(v => v[1])) - 0.5,
  maxX: Math.max(...ip.vertices.map(v => v[0])) + 0.5, maxY: Math.max(...ip.vertices.map(v => v[1])) + 0.5,
}))];

// ── Find entity handles that belong to the target tamanho ──

const entityIndexMap = new Map();
if (parsed.entities && parsed.entities.length > 0) {
  for (let i = 0; i < parsed.entities.length; i++) {
    entityIndexMap.set(i, parsed.entities[i].handle || `__IDX_${i}`);
  }
}

const keepHandles = new Set();
if (parsed.entities && parsed.entities.length > 0) {
  for (let i = 0; i < parsed.entities.length; i++) {
    const entity = parsed.entities[i];
    let ebox = entityBbox(entity);

    if (!isFinite(ebox.minX) && entity.type === "INSERT" && entity.block) {
      const blocksByName = parsed._blocksByName || {};
      const block = blocksByName[entity.block];
      if (block && block.entities && block.entities.length > 0) {
        ebox = blockBbox(block.entities, blocksByName, 0);
        const ox = entity.x || 0;
        const oy = entity.y || 0;
        if (isFinite(ebox.minX) && (ox !== 0 || oy !== 0)) {
          ebox = { minX: ebox.minX + ox, minY: ebox.minY + oy, maxX: ebox.maxX + ox, maxY: ebox.maxY + oy };
        }
      }
    }

    if (!isFinite(ebox.minX) || !isFinite(ebox.maxX)) continue;
    const ecx = (ebox.minX + ebox.maxX) / 2;
    const ecy = (ebox.minY + ebox.maxY) / 2;
    for (const tb of allTargetBboxes) {
      if (ebox.maxX >= tb.minX && ebox.minX <= tb.maxX && ebox.maxY >= tb.minY && ebox.minY <= tb.maxY) {
        if (pointInPolygon(ecx, ecy, targetOuter.vertices) || (ecx >= targetPolyBbox.minX && ecx <= targetPolyBbox.maxX && ecy >= targetPolyBbox.minY && ecy <= targetPolyBbox.maxY)) {
          keepHandles.add(entityIndexMap.get(i));
          break;
        }
      }
    }
  }
}

if (keepHandles.size === 0) { console.error("No matching DXF entities found for position " + position); process.exit(1); }

// ── Filter raw DXF: keep only matching entities in ENTITIES section ──

const rawLines = content.split(/\r?\n/);

// Find ENTITIES section boundaries
let sectionStartIdx = -1;   // index of "0" before "SECTION" that starts ENTITIES
let sectionEndIdx = -1;     // index of "ENDSEC" that ends ENTITIES
let currentSection = null;

for (let i = 0; i < rawLines.length; i++) {
  if (rawLines[i].trim() === "0" && i + 2 < rawLines.length && rawLines[i + 1].trim() === "SECTION" && rawLines[i + 2].trim() === "2") {
    // Look for section name on next line
    if (i + 3 < rawLines.length && rawLines[i + 3].trim() === "ENTITIES") {
      sectionStartIdx = i;
    }
  }
  if (sectionStartIdx !== -1 && sectionEndIdx === -1 && rawLines[i].trim() === "ENDSEC") {
    sectionEndIdx = i;
    break;
  }
}

if (sectionStartIdx === -1 || sectionEndIdx === -1) {
  console.error("Could not find ENTITIES section in DXF");
  process.exit(1);
}

// Extract entity blocks from ENTITIES section
// Each entity starts with group 0 + entity type, and ends just before the next group 0
// Track by handle when available, fall back to sequential index
const entityBlocks = [];
let currentBlock = [];
let currentHandle = null;
let inEntity = false;
let entityIndex = 0;

for (let i = sectionStartIdx; i <= sectionEndIdx; i++) {
  const line = rawLines[i];

  // Group code 5 = handle (within an entity block)
  if (line.trim() === "5" && inEntity && i + 1 < rawLines.length) {
    const handle = rawLines[i + 1].trim();
    if (/^[0-9A-Fa-f]+$/.test(handle)) {
      currentHandle = handle;
    }
  }

  // Group code 0 marks start of a new entity type
  if (line.trim() === "0" && i + 1 < rawLines.length) {
    const nextVal = rawLines[i + 1].trim();
    const entityTypes = ["SPLINE", "LWPOLYLINE", "LINE", "POLYLINE", "ARC", "CIRCLE", "ELLIPSE", "POINT", "INSERT", "TEXT", "MTEXT", "DIMENSION", "HATCH", "SOLID", "3DFACE", "VERTEX"];
    if (entityTypes.includes(nextVal)) {
      if (inEntity && currentBlock.length > 0) {
        const lookupKey = currentHandle || `__IDX_${entityIndex}`;
        entityBlocks.push({ handle: currentHandle, lookupKey, lines: currentBlock });
        entityIndex++;
      }
      currentBlock = [line];
      currentHandle = null;
      inEntity = true;
      continue;
    }
    if (nextVal === "ENDSEC" || nextVal === "EOF") {
      if (inEntity && currentBlock.length > 0) {
        const lookupKey = currentHandle || `__IDX_${entityIndex}`;
        entityBlocks.push({ handle: currentHandle, lookupKey, lines: currentBlock });
        entityIndex++;
      }
      currentBlock = [];
      currentHandle = null;
      inEntity = false;
      continue;
    }
  }

  if (inEntity) {
    currentBlock.push(line);
  }
}

// Build new ENTITIES section
const keptEntities = entityBlocks.filter(b => keepHandles.has(b.lookupKey));
if (keptEntities.length === 0) {
  console.error("No entities matched for position " + position);
  process.exit(1);
}

// Reconstruct DXF: original before ENTITIES + new ENTITIES section + original after ENTITIES
const beforeEntities = rawLines.slice(0, sectionStartIdx);
const afterEntities = rawLines.slice(sectionEndIdx + 1);

const newEntitiesLines = [
  "  0",
  "SECTION",
  "  2",
  "ENTITIES"
];
for (const entity of keptEntities) {
  newEntitiesLines.push(...entity.lines);
}
newEntitiesLines.push("  0");
newEntitiesLines.push("ENDSEC");

const outputContent = [...beforeEntities, ...newEntitiesLines, ...afterEntities].join("\n");

const outDir = path.dirname(outputPath);
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outputPath, outputContent, "latin1");
console.log(JSON.stringify({ ok: true, output: outputPath, kept_entities: keptEntities.length }));