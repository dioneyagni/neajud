#!/usr/bin/env node
// A simple nesting of one size's piece on a fabric roll (Etapa 2.2, 1/3;
// decided 07/10/2026): how many meters of roll one piece takes, for the
// cutting's expected metragem. Not a real marker — only copies of the same
// piece, turned as the corte allows (decided 08/10/2026, the corte page's
// "Giro no encaixe"): "nenhum" (as drawn), "180" (default) or "90" (0°, 90°,
// 180°, 270°).
//
// The DXF's vertical axis runs along the roll; its horizontal axis is the
// roll's width (decided 07/10/2026). The outer contour is drawn on a grid of
// `grade` mm: for each column across the roll, where the piece starts and
// ends along it (rounded outwards, which leaves about one cell between
// pieces). Copies are placed one by one at the column offset and turn that
// end the lowest, against the "frontier" each column has reached, until the
// roll is filled for ~4 m. Meters per piece = the average frontier of the
// columns used ÷ copies.
//
// With --svg <file>, also draws the fit (each copy where and how it was
// placed, and the 1 m mark) to check the result by eye.
//
// Usage: encaixe-dxf.js <tamanho.dxf> <roll width mm> [grade mm] [--giro nenhum|180|90] [--svg out.svg]
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
  const contorno = vertices.map(([x, y]) => [x - x0, y - y0]);
  const faixas = [];
  for (let c = 0; c < colunas; c++) {
    const cruzamentos = cruzamentosNaColuna(vertices, x0 + (c + 0.5) * grade);
    faixas.push(cruzamentos.length ? [Math.floor((Math.min(...cruzamentos) - y0) / grade), Math.ceil((Math.max(...cruzamentos) - y0) / grade)] : null);
  }
  return { faixas, altura, contorno, girada: false, quarto: false };
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
function girado(peca) {
  const { faixas, altura } = peca;
  return { ...peca, faixas: faixas.slice().reverse().map((f) => (f ? [altura - f[1], altura - f[0]] : null)), girada: true };
}

// The orientations a corte's "giro" allows; 90° adds the piece turned a
// quarter (its contour rotated, profiled again) and that one turned over.
const GIROS = ["nenhum", "180", "90"];
function orientacoesDo(giro, vertices, grade) {
  const normal = perfil(vertices, grade);
  if (giro === "nenhum") return [normal];
  if (giro === "180") return [normal, girado(normal)];
  const quarto = { ...perfil(vertices.map(([x, y]) => [y, -x]), grade), quarto: true };
  return [normal, girado(normal), quarto, girado(quarto)];
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

function encaixar(vertices, larguraMm, grade, giro = "180") {
  const fronteira = new Array(Math.floor(larguraMm / grade)).fill(0);
  const orientacoes = orientacoesDo(giro, vertices, grade).filter((peca) => peca.faixas.length <= fronteira.length);
  if (orientacoes.length === 0) return { metros_por_peca: null, copias: 0, largura_mm: larguraMm, colocadas: [], comprimento_mm: 0 };

  const colocadas = [];
  while (Math.max(...fronteira) * grade < COMPRIMENTO_ALVO_MM && colocadas.length < COPIAS_MAXIMAS) {
    const { peca, inicio, base } = melhorPosicao(fronteira, orientacoes);
    peca.faixas.forEach((f, c) => { if (f) fronteira[inicio + c] = base + f[1]; });
    colocadas.push({ peca, inicio, base });
  }
  // The length used: the average of the strips across the roll the fit
  // reached. A strip no copy ever reached (the edge left over when the pieces
  // don't fill the width) is waste but doesn't shorten the roll used — it
  // counted as length 0 and made a 300 mm piece on a 450 mm roll look 2/3 of
  // its real consumption (08/10/2026).
  const usadas = fronteira.filter((altura) => altura > 0);
  const media = usadas.reduce((a, b) => a + b, 0) / usadas.length;
  const copias = colocadas.length;
  return { metros_por_peca: Number(((media * grade) / 1000 / copias).toFixed(5)), copias, largura_mm: larguraMm, colocadas, comprimento_mm: Math.max(...fronteira) * grade };
}

// The fit drawn: the roll (width across, length down), each copy's contour
// where it was placed (turned ones in another color) and the 1 m mark.
function desenhar({ colocadas, largura_mm, comprimento_mm }, grade) {
  const pecas = colocadas.map(({ peca, inicio, base }) => {
    const largura = peca.faixas.length * grade;
    const altura = peca.altura * grade;
    const pontos = peca.contorno.map(([x, y]) => (peca.girada ? [largura - x, altura - y] : [x, y]))
      .map(([x, y]) => `${(inicio * grade + x).toFixed(1)},${(base * grade + y).toFixed(1)}`).join(" ");
    const cor = peca.quarto ? (peca.girada ? "#c9b3e6" : "#b3e6c2") : (peca.girada ? "#f6c9a8" : "#a8c8f6");
    return `<polygon points="${pontos}" fill="${cor}" stroke="#333" stroke-width="1"/>`;
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-10 -10 ${largura_mm + 20} ${comprimento_mm + 20}">
<rect x="0" y="0" width="${largura_mm}" height="${comprimento_mm}" fill="#fff" stroke="#999" stroke-width="2"/>
${pecas.join("\n")}
<line x1="-10" y1="1000" x2="${largura_mm + 10}" y2="1000" stroke="#c00" stroke-width="3" stroke-dasharray="20 10"/>
</svg>`;
}

if (require.main === module) {
  const args = process.argv.slice(2);
  const opcao = (nome) => { const i = args.indexOf(nome); return i >= 0 ? args.splice(i, 2)[1] : null; };
  const svg = opcao("--svg");
  const giro = opcao("--giro") || "180";
  const [caminho, largura, grade = "2"] = args;
  if (!caminho || !largura || !fs.existsSync(caminho) || !GIROS.includes(giro)) {
    console.error(`Usage: encaixe-dxf.js <tamanho.dxf> <roll width mm> [grade mm] [--giro ${GIROS.join("|")}] [--svg out.svg]; got ${JSON.stringify(process.argv.slice(2))}`);
    process.exit(1);
  }
  const vertices = contornoExterno(caminho);
  if (vertices.length < 3) {
    console.error(`No closed contour in ${caminho}`);
    process.exit(1);
  }
  const resultado = encaixar(vertices, Number(largura), Number(grade), giro);
  if (svg) fs.writeFileSync(svg, desenhar(resultado, Number(grade)));
  const { colocadas, ...saida } = resultado;
  console.log(JSON.stringify({ metros_por_peca: saida.metros_por_peca, copias: saida.copias, largura_mm: saida.largura_mm }));
}

module.exports = { encaixar, perfil, girado, orientacoesDo };
