// Painel 3/4a (decided 07/11/2026): moving a stage in its sector's queue.
// Two tecido pedidos of one client, confirmed one after the other, in the
// Impressão queue. ↑ on the second opens the impact window (centred) with
// the first among the pushed; Cancel changes nothing. With the first's
// deadline on its previsão day, putting the second ahead makes it late: the
// reason is required, then the move is saved, the page refreshes by itself
// (no reload), the line shows who moved it, the first's faixa and resumo
// say what it did. "Voltar tudo à ordem de chegada" takes it back. The
// turnos and rhythms come from parametros-producao and painel, run before;
// alone, this spec registers a 24 h turno.
const { BASE_URL, runSpec } = require("./support/runner");
const { prepararCorrida, pedidoDaCorrida, limparCorrida } = require("./support/corrida");
const { waitForText } = require("./support/wait");

runSpec("Painel Programação E2E Tests", async ({ page, test }) => {
  const ids = {};
  let corrida;

  function naFila(uuid) {
    return page.locator(`[data-fila-setor='impressao'] [data-fila-pedido='${uuid}']`).first();
  }

  async function posicao(uuid) {
    return Number((await naFila(uuid).locator(".painel-fila-pos").innerText()).replace("º", ""));
  }

  async function abrirFila() {
    await page.goto(`${BASE_URL}/painel`);
    await page.locator(".painel-setor[data-setor='impressao']").click();
    await naFila(ids.segundo).waitFor();
  }

  const janela = () => page.locator("dialog#painel_impacto_janela");

  // ↑ on the second, then its place set right above the first.
  async function moverParaAntesDoPrimeiro() {
    const alvo = await posicao(ids.primeiro);
    await naFila(ids.segundo).locator("[data-mover='subir']").click();
    await janela().locator("h3").waitFor();
    if (!(await janela().evaluate((d) => d.open))) throw new Error("The impact window didn't open");
    if ((await janela().locator("#impacto-posicao").inputValue()) !== String(alvo)) {
      await janela().locator("#impacto-posicao").selectOption(String(alvo));
      await janela().locator("h3", { hasText: `→ ${alvo}º` }).waitFor();
    }
    await janela().locator(`[data-impacto-empurrado='${ids.primeiro}']`).waitFor();
    return alvo;
  }

  await test("Setup: a client's fabric, his corrida, two pedidos confirmed one after the other; a turno and the tecido's rhythms", async () => {
    corrida = await prepararCorrida(page, "prog");
    ids.primeiro = await pedidoDaCorrida(page, corrida);
    ids.segundo = await pedidoDaCorrida(page, corrida);
    if (ids.primeiro === ids.segundo) throw new Error("Both items went into one pedido");

    await page.goto(`${BASE_URL}/parametros/turnos`);
    if (await page.getByText("No turno yet").count()) {
      const novo = "form.turno-novo";
      await page.fill(`${novo} input[name="turno[nome]"]`, "Programação 24h");
      await page.fill(`${novo} input[name="turno[inicio]"]`, "00:00");
      await page.fill(`${novo} input[name="turno[fim]"]`, "23:59");
      for (const dia of [0, 6]) await page.check(`${novo} input[name="turno[dias][]"][value="${dia}"]`);
      await page.click(`${novo} input[type="submit"][value="Add turno"]`);
      await waitForText(page, "Turno Programação 24h saved.");
    }
    // A slow Calandra: each pedido's takes a day or more, so a move changes days.
    await page.goto(`${BASE_URL}/parametros/ritmos/edit`);
    await page.fill('input[name="ritmos[tecido][impressao][por_hora]"]', "100");
    await page.fill('input[name="ritmos[tecido][calandra][por_hora]"]', "0,5");
    await page.evaluate(() => { document.body.dataset.antesDeSalvar = "1" });
    await page.click('.ritmos-form button[type="submit"]');
    await page.waitForSelector("body:not([data-antes-de-salvar])");
    await waitForText(page, "Production rhythm saved.");
  });

  await test("↑ opens the impact window, centred, with the first among the pushed; Cancel changes nothing", async () => {
    await abrirFila();
    const antes = await posicao(ids.segundo);
    if (antes <= (await posicao(ids.primeiro))) throw new Error("The second is not after the first");
    await moverParaAntesDoPrimeiro();
    const caixa = await janela().evaluate((d) => { const r = d.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2, w: innerWidth, h: innerHeight } });
    if (Math.abs(caixa.x - caixa.w / 2) > 2 || Math.abs(caixa.y - caixa.h / 2) > 2) throw new Error(`Not centred: ${JSON.stringify(caixa)}`);
    ids.dia = await janela().locator(`[data-impacto-empurrado='${ids.primeiro}']`).getAttribute("data-de");
    await janela().locator(".painel-impacto-cancelar").click();
    if (await janela().evaluate((d) => d.open)) throw new Error("Cancel didn't close the window");
    if ((await posicao(ids.segundo)) !== antes) throw new Error("Cancel moved it");
  });

  await test("Ahead of the first, whose deadline is its previsão's day, the move needs a reason; saved, the page refreshes itself and the line says who moved it", async () => {
    await page.goto(`${BASE_URL}/pedidos/${ids.primeiro}/resumo`);
    await page.fill("#prazo_entrega", ids.dia);
    await page.click(".pedido-prazo-form button[type=submit]");
    await waitForText(page, "Prazo de entrega atualizado.");
    await abrirFila();
    const alvo = await moverParaAntesDoPrimeiro();
    if ((await janela().locator(`[data-impacto-empurrado='${ids.primeiro}']`).getAttribute("data-passa-a-atrasar")) !== "true") throw new Error("The first doesn't come to be late");
    // Without a reason it can't be sent.
    await janela().locator(".painel-impacto-confirmar").click();
    if (!(await janela().locator("#impacto-motivo").evaluate((t) => t.matches(":invalid")))) throw new Error("The reason isn't required");
    if (!(await janela().evaluate((d) => d.open))) throw new Error("It went without a reason");
    await page.evaluate(() => { window.semRecarregar = true });
    await janela().locator("#impacto-motivo").fill("cliente pediu urgência");
    await Promise.all([
      page.waitForResponse((r) => new URL(r.url()).pathname === "/painel" && r.request().method() === "GET"),
      janela().locator(".painel-impacto-confirmar").click(),
    ]);
    await naFila(ids.segundo).locator("[data-fila-movida]").waitFor();
    if (await janela().evaluate((d) => d.open)) throw new Error("The window stayed open");
    if (!(await page.evaluate(() => window.semRecarregar))) throw new Error("The page reloaded");
    if ((await posicao(ids.segundo)) !== alvo) throw new Error(`Not at ${alvo}º`);
    if ((await posicao(ids.primeiro)) !== alvo + 1) throw new Error("The first is not right after it");
    if (!(await naFila(ids.segundo).locator("[data-fila-movida]").innerText()).startsWith("↑ movida · Operador E2E")) throw new Error("The badge doesn't say who");
  });

  await test("The first's faixa and resumo tell what the move did to it; the resumo's Histórico says its previsão changed", async () => {
    await page.locator(".painel-setor[data-setor='']").click();
    await page.locator(`#painel_${ids.primeiro} .painel-ped-btn`).first().click();
    const historico = await page.locator(`#painel_${ids.primeiro} > .painel-faixa [data-historico-programacao]`).innerText();
    if (!historico.includes("cliente pediu urgência") || !historico.includes("este pedido:")) throw new Error(`Its faixa says: ${historico}`);
    await page.goto(`${BASE_URL}/pedidos/${ids.primeiro}/resumo`);
    await page.locator("[data-historico-programacao]").waitFor();
    const eventos = await page.locator(".pedido-eventos li span").allInnerTexts();
    if (!eventos.some((e) => /^previsão mudou: .+ → .+ \(reprogramação da fábrica\)$/.test(e))) throw new Error(`Its Histórico: ${eventos.join(" | ")}`);
  });

  await test("\"Voltar tudo à ordem de chegada\" takes the queue back", async () => {
    await abrirFila();
    await page.locator("[data-fila-setor='impressao'] .painel-fila-voltar").click();
    await janela().locator("h3", { hasText: "voltar tudo à ordem de chegada" }).waitFor();
    await janela().locator("#impacto-motivo").fill("volta");
    await Promise.all([
      page.waitForResponse((r) => new URL(r.url()).pathname === "/painel" && r.request().method() === "GET"),
      janela().locator(".painel-impacto-confirmar").click(),
    ]);
    await naFila(ids.segundo).locator("[data-fila-movida]").waitFor({ state: "detached" });
    if ((await posicao(ids.segundo)) <= (await posicao(ids.primeiro))) throw new Error("The second is still ahead");
    limparCorrida(corrida);
  });
});
