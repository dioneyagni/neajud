// Máquinas 2/5a (decided 20–21/11/2026, the 4B mockup in the canvas
// "Máquinas"): a sector with machines shows its first turno's lanes, a chip
// per machine filtering the list — kept on a reload —, and the Máquina
// column; each pedido's Calandra goes whole on the machine that ends it
// first (Q3a). Máquinas 2/5b: ⇄ sends it to another machine through the
// impact window — Cancel changes nothing, Confirm holds it there (its badge,
// its line in the history) —, and the window takes it back to the
// automatic. Máquinas 4/5a: the Calandra's baixa names its machine.
// Máquinas 3/5b: ⏸ on a lane stops its machine, "voltou a funcionar". Last, its machines go to the trash: the specs after this one
// type their rhythms in Ritmos.
const { BASE_URL, runSpec } = require("./support/runner");
const { prepararCorrida, pedidoDaCorrida, limparCorrida } = require("./support/corrida");
const { waitForText } = require("./support/wait");

runSpec("Painel Máquinas E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const epson = `Epson P ${U}`;
  const calandras = [ `Calandra P1 ${U}`, `Calandra P2 ${U}` ];
  let corrida;
  let pedido;

  async function novaMaquina(nome, trabalhos) {
    await page.goto(`${BASE_URL}/parametros/maquinas/new`);
    await page.fill("#maquina_nome", nome);
    for (const [chave, velocidade] of Object.entries(trabalhos)) {
      await page.check(`#trabalho_${chave}`);
      await page.fill(`[data-velocidade-de="${chave}"][name$="[por_hora]"]`, velocidade);
    }
    await page.click('button[form="maquina-form"]');
    await waitForText(page, `${nome}: salva.`);
  }

  async function abaDaEstamparia() {
    await page.goto(`${BASE_URL}/painel`);
    await page.locator(".painel-setor[data-setor='estamparia']").click();
    const fila = page.locator("[data-fila-setor='estamparia']");
    await fila.locator(`[data-fila-pedido='${pedido}']`).first().waitFor();
    return fila;
  }

  // Its first line: a piece spilling into the next turno has a "continuação" too.
  function linhaDoPedido(fila) {
    return fila.locator(`[data-fila-pedido='${pedido}']`).first();
  }

  function chip(fila, nome) {
    return fila.locator(".painel-fila-filtro-chip", { hasText: nome });
  }

  await test("A sector with machines shows their lanes and the Máquina column", async () => {
    corrida = await prepararCorrida(page, "pmaq");
    pedido = await pedidoDaCorrida(page, corrida);
    await page.goto(`${BASE_URL}/parametros/turnos`);
    if (await page.getByText("No turno yet").count()) {
      const novo = "form.turno-novo";
      await page.fill(`${novo} input[name="turno[nome]"]`, "Máquinas 24h");
      await page.fill(`${novo} input[name="turno[inicio]"]`, "00:00");
      await page.fill(`${novo} input[name="turno[fim]"]`, "23:59");
      for (const dia of [0, 6]) await page.check(`${novo} input[name="turno[dias][]"][value="${dia}"]`);
      await page.click(`${novo} input[type="submit"][value="Add turno"]`);
      await waitForText(page, "Turno Máquinas 24h saved.");
    }
    await novaMaquina(epson, { impressao_papel: "100" });
    for (const nome of calandras) await novaMaquina(nome, { calandra: "25" });

    const fila = await abaDaEstamparia();
    const raias = await fila.locator("[data-fila-raias] .painel-raia-nome b").allInnerTexts();
    for (const nome of calandras) if (!raias.includes(nome)) throw new Error(`The lanes are ${JSON.stringify(raias)}, expected ${nome} among them`);
    const livres = await fila.locator("[data-fila-raias] [data-fila-livres]").first().innerText();
    if (!/livres$/.test(livres)) throw new Error(`A lane's free hours read "${livres}", expected "… livres"`);
    if (!(await fila.locator(".painel-fila-cab").innerText()).includes("MÁQUINA")) throw new Error("The queue has no Máquina column");
    const maquina = (await linhaDoPedido(fila).locator("[data-fila-na-maquina]").innerText()).trim();
    if (!calandras.includes(maquina)) throw new Error(`The pedido's Calandra is on "${maquina}", expected one of ${calandras.join(", ")}`);
  });

  await test("A machine's chip filters the list, kept on a reload; Todas shows every one again", async () => {
    let fila = await abaDaEstamparia();
    const linha = () => fila.locator(`[data-fila-pedido='${pedido}']`).first();
    const dela = (await linha().locator("[data-fila-na-maquina]").innerText()).trim();
    const outra = calandras.find((nome) => nome !== dela);

    // The other machine's operator doesn't see this piece: it isn't his.
    await chip(fila, outra).click();
    await linha().waitFor({ state: "hidden" });
    await chip(fila, dela).click();
    await linha().waitFor({ state: "visible" });

    await page.reload();
    await page.locator(".painel-setor[data-setor='estamparia']").click();
    fila = page.locator("[data-fila-setor='estamparia']");
    await linha().waitFor({ state: "visible" });
    if ((await chip(fila, dela).getAttribute("aria-pressed")) !== "true") throw new Error(`After a reload the chip of ${dela} is not the one pressed`);
    // Every row left in view is on that machine.
    const outrasVisiveis = await fila.locator("[data-fila-pedido]:visible").evaluateAll((linhas) => linhas.filter((l) => l.querySelector("[data-fila-na-maquina]")?.textContent.trim() !== l.closest("[data-fila-setor]").querySelector(".painel-fila-filtro-chip--ativo").textContent.trim()).length);
    if (outrasVisiveis !== 0) throw new Error(`${outrasVisiveis} rows of another machine still show with ${dela} picked`);

    await chip(fila, "Todas as máquinas").click();
    const escondidas = await fila.locator(".painel-fila-l--outra-maquina").count();
    if (escondidas !== 0) throw new Error(`${escondidas} rows stay hidden with every machine picked`);
  });

  async function abrirMandar() {
    const fila = await abaDaEstamparia();
    await linhaDoPedido(fila).locator("[data-mover='maquina']").click();
    const janela = page.locator("#painel_impacto_janela");
    await janela.locator("#impacto-maquina").waitFor();
    return janela;
  }

  async function maquinaDaCalandra(fila) {
    return (await linhaDoPedido(fila).locator("[data-fila-na-maquina]").innerText()).trim();
  }

  await test("⇄ opens the window centred; Cancel sends nothing", async () => {
    const antes = await maquinaDaCalandra(await abaDaEstamparia());
    const janela = await abrirMandar();
    const escolhida = (await janela.locator("#impacto-maquina option:checked").innerText()).trim();
    if (escolhida === antes || !calandras.includes(escolhida)) throw new Error(`The window picks "${escolhida}", expected the other Calandra (the piece is on ${antes})`);
    const caixa = await janela.boundingBox();
    const tela = page.viewportSize();
    if (Math.abs(caixa.x + caixa.width / 2 - tela.width / 2) > 4) throw new Error(`The window isn't centred: x ${caixa.x}, width ${caixa.width} on ${tela.width}`);

    await janela.locator(".painel-impacto-cancelar").click();
    await janela.waitFor({ state: "hidden" });
    const fila = await abaDaEstamparia();
    if ((await maquinaDaCalandra(fila)) !== antes) throw new Error("Cancel moved the piece to another machine");
    if (await linhaDoPedido(fila).locator("[data-fila-presa]").count()) throw new Error("Cancel left the piece held");
  });

  await test("Confirm holds it on the other machine, its badge and history say so", async () => {
    const antes = await maquinaDaCalandra(await abaDaEstamparia());
    const janela = await abrirMandar();
    const outra = (await janela.locator("#impacto-maquina option:checked").innerText()).trim();
    await janela.locator("#impacto-motivo").fill("feltro novo");
    await janela.locator(".painel-impacto-confirmar").click();
    await janela.waitFor({ state: "hidden" });

    const fila = await abaDaEstamparia();
    const presa = linhaDoPedido(fila).locator("[data-fila-presa]");
    await presa.waitFor();
    if (!(await presa.innerText()).startsWith(`● presa na ${outra} · `)) throw new Error(`The badge reads "${await presa.innerText()}", expected it held on ${outra}`);
    if ((await maquinaDaCalandra(fila)) !== outra) throw new Error(`The piece is on "${await maquinaDaCalandra(fila)}", expected ${outra}`);
    await page.goto(`${BASE_URL}/pedidos/${pedido}/resumo`);
    await waitForText(page, `mandou a Calandra do #${pedido.slice(0, 8)} da ${antes} para a ${outra} · feltro novo`);
  });

  await test("The window takes a held piece back to the automatic", async () => {
    const janela = await abrirMandar();
    await janela.locator("[data-impacto-automatico]").click();
    await janela.locator("#titulo-impacto", { hasText: "voltar ao automático" }).waitFor();
    await janela.locator(".painel-impacto-confirmar").click();
    await janela.waitFor({ state: "hidden" });
    const fila = await abaDaEstamparia();
    await linhaDoPedido(fila).locator("[data-fila-presa]").waitFor({ state: "detached" });
    await page.goto(`${BASE_URL}/pedidos/${pedido}/resumo`);
    await waitForText(page, `voltou a Calandra do #${pedido.slice(0, 8)} ao automático`);
  });

  // Máquinas 4/5a: the Calandra's baixa asks which machine (one per baixa),
  // opening on the suggested one — here the queue's, fetched as it opens.
  await test("The Calandra's baixa asks the machine, opening on the queue's, and says it once saved", async () => {
    // The test server has no forgery protection: no csrf meta to send.
    await page.goto(`${BASE_URL}/painel`);
    const resposta = await page.evaluate(async (url) => {
      const csrf = document.querySelector("meta[name='csrf-token']")?.content || "";
      const body = new FormData();
      Object.entries({ etapa: "impressao", nivel: "pedido", medida: "1", confirmar: "1" }).forEach(([c, v]) => body.append(c, v));
      const r = await fetch(url, { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": csrf }, body });
      return r.json();
    }, `${BASE_URL}/pedidos/${pedido}/baixas`);
    if (!resposta.ok) throw new Error(`The Impressão's baixa answered ${JSON.stringify(resposta)}`);
    // The Impressão done moves the queue: the Calandra's machine is read after it.
    const naFila = await maquinaDaCalandra(await abaDaEstamparia());

    await page.goto(`${BASE_URL}/pedidos/${pedido}/tecido/producao/calandra`);
    const baixa = page.locator(".baixa").filter({ has: page.locator("select.baixa-maquina") }).first();
    const sugerida = page.waitForResponse((r) => r.url().includes("/baixas/maquina"));
    await baixa.locator(".baixa-abrir").click();
    await sugerida;
    const select = baixa.locator("select.baixa-maquina");
    await select.locator("option:checked", { hasText: naFila }).waitFor({ state: "attached" });
    const opcoes = (await select.locator("option").allInnerTexts()).map((t) => t.trim());
    for (const nome of calandras) if (!opcoes.includes(nome)) throw new Error(`The machines offered are ${JSON.stringify(opcoes)}, expected ${nome} among them`);

    const outra = calandras.find((nome) => nome !== naFila);
    await select.selectOption({ label: outra });
    await baixa.locator("input.baixa-medida").fill("1");
    await baixa.locator(".baixa-salvar").click();
    // 1 m is outside the band of either line: the warning asks to confirm.
    await baixa.locator(".baixa-confirmar").click();
    await waitForText(page, `na ${outra}.`);
    await page.locator(".baixa-feita-maquina", { hasText: outra }).first().waitFor();
  });

  // Máquinas 3/5b (Q1a, Q7a): ⏸ on a Calandra's lane stops it — the
  // pieces waiting for it are RSpec's (parada_no_painel_spec): the baixa
  // above may have ended this pedido's Calandra.
  await test("⏸ on a lane stops its machine: the window warns, the lane says so, and it comes back", async () => {
    const nome = calandras[0];
    const raiaDela = () => page.locator("[data-fila-setor='estamparia'] .painel-raia", { hasText: nome });
    const abrir = async () => {
      await page.goto(`${BASE_URL}/painel`);
      await page.locator(".painel-setor[data-setor='estamparia']").click();
      await raiaDela().waitFor();
    };
    await abrir();
    await raiaDela().locator(".painel-raia-parar").click();
    const janela = page.locator("#painel_impacto_janela");
    await janela.locator("[data-nova-parada]").waitFor();
    if (!(await janela.locator(".parada-maquina", { hasText: nome }).locator("input").isChecked())) throw new Error(`The window doesn't pick ${nome}`);
    await janela.locator("#parada_nome").fill(`Feltro ${U}`);
    await janela.locator('input[type="submit"]').click();
    await janela.locator("[data-parada-feita] [data-parada-aviso]").waitFor();
    await janela.locator('[data-parada-feita] button:has-text("Fechar")').click();
    await janela.waitFor({ state: "hidden" });

    await abrir();
    const parada = raiaDela().locator("[data-raia-parada]");
    await parada.waitFor();
    if (!(await parada.innerText()).includes(`Feltro ${U}`)) throw new Error(`The lane says "${await parada.innerText()}"`);
    if (!(await page.locator("[data-fila-setor='estamparia'] [data-fila-paradas]").innerText()).includes("1 parada")) throw new Error("The header doesn't count the stop");

    await raiaDela().locator('button:has-text("Voltou a funcionar")').click();
    await waitForText(page, `Feltro ${U}: voltou a funcionar.`);
    await abrir();
    await raiaDela().locator(".painel-raia-parar").waitFor();
  });

  await test("Cleanup: its machines to the trash", async () => {
    for (const nome of [ epson, ...calandras ]) {
      await page.goto(`${BASE_URL}/parametros/maquinas`);
      await page.locator(`tr[data-maquina="${nome}"] button:has-text("Lixeira")`).click();
      await waitForText(page, `${nome}: foi para a lixeira.`);
    }
    // The filter kept for the tab goes back to every machine for whoever comes next.
    await page.evaluate(() => sessionStorage.removeItem("painel:maquina:estamparia"));
    limparCorrida(corrida);
  });
});
