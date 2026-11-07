// Painel 3/4b (decided 07/11/2026): after a virada. The factory's turnos go
// to the trash and one "Virada 24h" every day takes their place, so the last
// turno over is yesterday's; the tecido's rhythms are fast, the pedido's
// deadline is yesterday. The photos of yesterday's turno and today's are
// taken by the app's own service (e2e/support/fotos_da_virada.rb) — nothing
// was done yesterday. The Painel then warns that the pedido came to be late
// (Q5a); clicked, from the Linha do tempo, it opens in the grid; its
// Impressão in the queue and its cell say "veio de ontem" (Q3a); its faixa
// and its resumo tell the virada, the resumo's Histórico the cliente final's
// "previsão mudou" (Q6a). Painel 3/4b2: a second pedido arrives after it;
// the faixa draws yesterday's plan dashed with an arrow to today (Q8a), and
// "mostrar quem cruzou" lists and marks the second one, held by it (Q9a).
// Runs last: the turnos it trashed stay so.
const { execFileSync } = require("child_process");
const path = require("path");
const { BASE_URL, runSpec } = require("./support/runner");
const { prepararCorrida, pedidoDaCorrida, limparCorrida } = require("./support/corrida");
const { waitForText } = require("./support/wait");

runSpec("Painel Virada E2E Tests", async ({ page, test }) => {
  const ids = {};
  let corrida;
  let virada;
  const turno = "Virada 24h";

  await test("Setup: a pedido of a corrida due yesterday, one turno every day, fast rhythms, the photos of yesterday and today", async () => {
    corrida = await prepararCorrida(page, "virada");
    ids.pedido = await pedidoDaCorrida(page, corrida);
    ids.depois = await pedidoDaCorrida(page, corrida);
    const ontem = new Date(Date.now() - 24 * 3600 * 1000).toLocaleDateString("sv-SE", { timeZone: "America/Sao_Paulo" });
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await page.fill("#prazo_entrega", ontem);
    await page.click(".pedido-prazo-form button[type=submit]");
    await waitForText(page, "Prazo de entrega atualizado.");

    await page.goto(`${BASE_URL}/parametros/turnos`);
    // The confirm is accepted by the runner.
    while (await page.locator("form[data-turno] a:has-text('Trash')").count()) {
      const nome = await page.locator("form[data-turno]").first().getAttribute("data-turno");
      await page.locator("form[data-turno]").first().locator("a:has-text('Trash')").click();
      await waitForText(page, `Turno ${nome} moved to the trash.`);
    }
    const novo = "form.turno-novo";
    await page.fill(`${novo} input[name="turno[nome]"]`, turno);
    await page.fill(`${novo} input[name="turno[inicio]"]`, "00:00");
    await page.fill(`${novo} input[name="turno[fim]"]`, "23:59");
    for (const dia of [0, 6]) await page.check(`${novo} input[name="turno[dias][]"][value="${dia}"]`);
    await page.click(`${novo} input[type="submit"][value="Add turno"]`);
    await waitForText(page, `Turno ${turno} saved.`);
    await page.goto(`${BASE_URL}/parametros/ritmos/edit`);
    await page.fill('input[name="ritmos[tecido][impressao][por_hora]"]', "100");
    await page.fill('input[name="ritmos[tecido][calandra][por_hora]"]', "100");
    await page.evaluate(() => { document.body.dataset.antesDeSalvar = "1" });
    await page.click('.ritmos-form button[type="submit"]');
    await page.waitForSelector("body:not([data-antes-de-salvar])");
    await waitForText(page, "Production rhythm saved.");

    const saida = execFileSync(path.join(__dirname, "..", "bin", "rails"), ["runner", path.join(__dirname, "support", "fotos_da_virada.rb"), ids.pedido],
                               { env: { ...process.env, RAILS_ENV: "test" }, encoding: "utf8" });
    virada = JSON.parse(saida.trim().split("\n").pop());
    if (virada.anterior !== turno) throw new Error(`The turno over is ${virada.anterior}, not ${turno}`);
    if (!virada.terminam) throw new Error("Yesterday's photo didn't have the pedido end yesterday: the queue ahead of it is too long");
    if (virada.viradas !== 1) throw new Error(`The virada told the pedido ${virada.viradas} times`);
  });

  await test("The warning on top names the pedido that came to be late; clicked from the Linha do tempo, it opens in the grid", async () => {
    await page.goto(`${BASE_URL}/painel?visao=tempo`);
    const aviso = page.locator("[data-painel-virada]");
    const texto = await aviso.locator("strong").innerText();
    if (!/^Na virada para a Virada 24h, \d+ pedidos? (passou|passaram) a atrasar:$/.test(texto)) throw new Error(`The warning says "${texto}"`);
    await aviso.locator(`button[data-pedido='${ids.pedido}']`).click();
    const linha = page.locator(`#painel_${ids.pedido}`);
    await linha.locator(".painel-faixa").waitFor({ state: "visible" });
    if (await page.locator("[data-painel-target='tempo']").isVisible()) throw new Error("The Linha do tempo is still shown");
    if ((await linha.locator(".painel-ped-btn").first().getAttribute("aria-expanded")) !== "true") throw new Error("The pedido didn't open");
    if (new URL(page.url()).searchParams.get("visao") === "tempo") throw new Error("The address kept the Linha do tempo");
  });

  await test("Its Impressão in the queue and its cell say it came from yesterday's turno", async () => {
    const titulo = await page.locator(`#painel_${ids.pedido} > .painel-linha [data-coluna='impressao']`).getAttribute("title");
    if (!titulo.includes(`Impressão: veio de ontem · ${turno}`)) throw new Error(`The cell says "${titulo}"`);
    await page.locator(".painel-setor[data-setor='impressao']").click();
    const selo = page.locator(`[data-fila-setor='impressao'] [data-fila-pedido='${ids.pedido}'] [data-fila-veio]`).first();
    if ((await selo.innerText()) !== `veio de ontem · ${turno}`) throw new Error(`The queue says "${await selo.innerText()}"`);
  });

  await test("Its faixa draws yesterday's plan dashed, an arrow to today, and marks who crossed it", async () => {
    await page.locator(".painel-setor[data-setor='']").click();
    const faixa = page.locator(`#painel_${ids.pedido} > .painel-faixa`);
    if (!(await faixa.locator("[data-tdp-plano]").count())) throw new Error("The faixa draws no plan");
    const seta = await faixa.locator("[data-tdp-seta]").first().innerText();
    if (seta !== "+1 turno") throw new Error(`The arrow says "${seta}"`);
    if (!(await faixa.locator(".painel-tdp-col--passada").count())) throw new Error("Yesterday's turno is not in the timeline");

    const botao = faixa.locator("[data-quem-cruzou] button");
    await botao.click();
    await faixa.locator(`[data-cruzamentos] a[href='/pedidos/${ids.depois}/resumo']`).first().waitFor({ state: "visible" });
    const linha = await faixa.locator("[data-cruzamento]").filter({ hasText: ids.depois.slice(0, 8) }).first().innerText();
    if (!linha.startsWith(`este pedido empurrou o #${ids.depois.slice(0, 8)} · `) || !linha.includes(`deste não terminou na ${turno}`)) throw new Error(`It says: ${linha}`);
    for (const id of [`painel_${ids.depois}`, `tempo_${ids.depois}`]) {
      if (!(await page.locator(`#${id}`).evaluate((e) => e.classList.contains("painel-cruzou")))) throw new Error(`#${id} is not marked`);
    }
    if (!(await botao.innerText()).startsWith("esconder quem cruzou")) throw new Error(`The button says "${await botao.innerText()}"`);
    await botao.click();
    await page.locator(".painel-cruzou").first().waitFor({ state: "detached" });
    if (!(await faixa.locator("[data-cruzamentos]").isHidden())) throw new Error("The list is still shown");
  });

  await test("Its faixa and resumo tell the virada; the resumo's Histórico says the previsão changed, from no one", async () => {
    await page.locator(".painel-setor[data-setor='']").click();
    const historico = await page.locator(`#painel_${ids.pedido} > .painel-faixa [data-historico-programacao]`).innerText();
    if (!historico.includes(`virada para a ${turno} · não terminaram na ${turno}: Impressão do #${ids.pedido.slice(0, 8)}`) || !historico.includes("passou a atrasar")) throw new Error(`Its faixa says: ${historico}`);
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    const evento = page.locator(".pedido-evento--previsao_mudou").last();
    if (!/^previsão mudou: .+ → .+ \(reprogramação da fábrica\)$/.test(await evento.locator("span").innerText())) throw new Error(`Its Histórico: ${await evento.innerText()}`);
    // A virada has no person behind it: the line names no one.
    if ((await evento.locator("small").innerText()).includes("·")) throw new Error(`It names someone: ${await evento.locator("small").innerText()}`);
    limparCorrida(corrida);
  });
});
