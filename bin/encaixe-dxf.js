#!/usr/bin/env node
// A simple nesting of one size's piece on a fabric roll (Etapa 2.2, 1/3;
// decided 07/10/2026): how many meters of roll one piece takes, for the
// cutting's expected metragem. Not a real marker — only copies of the same
// piece, turned 0° or 180° (the grain can't turn 90°).
//
// The DXF's vertical axis runs along the roll; its horizontal axis is the
// roll's width (decided 07/10/2026). The outer contour is drawn on a grid of
// `grade` mm: for each column across the roll, where the piece starts and
// ends along it (rounded outwards, which leaves about one cell between
// pieces). Copies are placed one by one at the column offset and turn that
// end the lowest, against the "frontier" each column has reached, until the
// roll is filled for ~4 m. Meters per piece = the average frontier ÷ copies.
//
// Usage: encaixe-dxf.js <tamanho.dxf> <roll width mm> [grade mm]
//   → {"metros_por_peca":0.0312,"copias":128,"largura_mm":1400}
//   → {"metros_por_peca":null,...} when the piece is wider than the roll
const fs = require("fs");
const dxf = require("dxf");

const COMPRIMENTO_ALVO_MM = 4000;
const COPIAS_MAXIMAS = 5000;

function contornoExterno(caminho) {
  const parsed = dxf.parseString(fs.readFileSync(caminho, "latin1"));
  const paraMm = parsed.header && parsed.header.insUnits === 1 ? 25.4 : 1;
  const polilinhas = (dxf.toPolylines(parsed).polylines || []).map((p) => p.vertices.map(([x, y]) => [x * paraMm, y * paraMm]));
  return polilinhas.reduce((maior, p) => (area(p) > area(maior) ? p : maior), []);
}

function area(vertices) {
  let soma = 0;
  for (let i = 0; i < vertices.length; i++) {
    const [x1, y1] = vertices[i];
    const [x2, y2] = vertices[(i + 1) % vertices.length];
    soma += x1 * y2 - x2 * y1;
  }
  return Math.abs(soma) / 2;
}

// Per column across the roll: [start, end] along it, in cells (null = empty).
function perfil(vertices, grade) {
  const xs = vertices.map((v) => v[0]);
  const ys = vertices.map((v) => v[1]);
  const [x0, y0] = [Math.min(...xs), Math.min(...ys)];
  const colunas = Math.ceil((Math.max(...xs) - x0) / grade);
  const altura = Math.ceil((Math.max(...ys) - y0) / grade);
  const faixas = [];
  for (let c = 0; c < colunas; c++) {
    const cruzamentos = cruzamentosNaColuna(vertices, x0 + (c + 0.5) * grade);
    faixas.push(cruzamentos.length ? [Math.floor((Math.min(...cruzamentos) - y0) / grade), Math.ceil((Math.max(...cruzamentos) - y0) / grade)] : null);
  }
  return { faixas, altura };
}

function cruzamentosNaColuna(vertices, x) {
  const ys = [];
  for (let i = 0; i < vertices.length; i++) {
    const [xa, ya] = vertices[i];
    const [xb, yb] = vertices[(i + 1) % vertices.length];
    if ((xa <= x && xb > x) || (xb <= x && xa > x)) ys.push(ya + ((x - xa) / (xb - xa)) * (yb - ya));
  }
  return ys;
}

// The same piece turned 180°: columns reversed, start/end mirrored.
function girado({ faixas, altura }) {
  return { faixas: faixas.slice().reverse().map((f) => (f ? [altura - f[1], altura - f[0]] : null)), altura };
}

// Where a piece rests at column offset `inicio`: the lowest start that clears
// every column's frontier.
function apoio(fronteira, peca, inicio) {
  let base = 0;
  peca.faixas.forEach((f, c) => { if (f) base = Math.max(base, fronteira[inicio + c] - f[0]); });
  return base;
}

function melhorPosicao(fronteira, orientacoes) {
  let melhor = null;
  for (const peca of orientacoes) {
    for (let inicio = 0; inicio + peca.faixas.length <= fronteira.length; inicio++) {
      const base = apoio(fronteira, peca, inicio);
      const topo = base + peca.altura;
      if (!melhor || topo < melhor.topo || (topo === melhor.topo && base < melhor.base)) melhor = { peca, inicio, base, topo };
    }
  }
  return melhor;
}

function encaixar(vertices, larguraMm, grade) {
  const normal = perfil(vertices, grade);
  const fronteira = new Array(Math.floor(larguraMm / grade)).fill(0);
  if (normal.faixas.length > fronteira.length) return { metros_por_peca: null, copias: 0, largura_mm: larguraMm };

  const orientacoes = [normal, girado(normal)];
  let copias = 0;
  while (Math.max(...fronteira) * grade < COMPRIMENTO_ALVO_MM && copias < COPIAS_MAXIMAS) {
    const { peca, inicio, base } = melhorPosicao(fronteira, orientacoes);
    peca.faixas.forEach((f, c) => { if (f) fronteira[inicio + c] = base + f[1]; });
    copias++;
  }
  const media = fronteira.reduce((a, b) => a + b, 0) / fronteira.length;
  return { metros_por_peca: Number(((media * grade) / 1000 / copias).toFixed(5)), copias, largura_mm: larguraMm };
}

if (require.main === module) {
  const [caminho, largura, grade = "2"] = process.argv.slice(2);
  if (!caminho || !largura || !fs.existsSync(caminho)) {
    console.error(`Usage: encaixe-dxf.js <tamanho.dxf> <roll width mm> [grade mm]; got ${JSON.stringify(process.argv.slice(2))}`);
    process.exit(1);
  }
  const vertices = contornoExterno(caminho);
  if (vertices.length < 3) {
    console.error(`No closed contour in ${caminho}`);
    process.exit(1);
  }
  console.log(JSON.stringify(encaixar(vertices, Number(largura), Number(grade))));
}

module.exports = { encaixar, perfil, girado };
