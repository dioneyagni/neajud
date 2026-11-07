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
const fs = require("fs");
const os = require("os");
const path = require("path");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Painel Programação E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { corrida: `corridaprog${U}`, cliente: `Malharia Prog ${U}`, grupo: `Helanca${U}` };
  const ids = {};
  // Outside the repo: an "e2e-" prefix would be read as part of the name.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "programacao-"));
  const original = path.join(pasta, `${nomes.corrida}.tif`);

  async function postar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  async function buscarJson(url) {
    return page.evaluate(async (url) => (await fetch(url, { headers: { Accept: "application/json" } })).json(), url);
  }

  // A pedido of the corrida, its fabric chosen, confirmed.
  async function pedidoConfirmado() {
    await page.goto(`${BASE_URL}/arquivos`);
    await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.locator(".add-to-order-metros").fill("12,5");
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    const uuid = (await resposta.json()).pedido_uuid;
    await page.goto(`${BASE_URL}/pedidos/${uuid}/resumo`);
    await page.locator("select.pedido-tecido-material").first().selectOption(ids.tecido);
    await page.locator(".pedido-pendencia--sem_material").waitFor({ state: "detached", timeout: 10000 });
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
    return uuid;
  }

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
    await page.goto(`${BASE_URL}/parametros/edit`);
    await page.fill("#empresa_preco_impressao_metro_tecido", "15");
    await page.click('input[type="submit"][value="Save"]');
    await waitForText(page, "Production parameters saved.");
    if (!(await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" }))) throw new Error("Couldn't create the client");
    ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
    await postar("/materiais/create_grupo", { "grupo_material[nome]": nomes.grupo });
    const grupo = (await buscarJson(`/materiais/grupos?q=${nomes.grupo}`)).find((g) => g.nome === nomes.grupo).id;
    const cor = (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco")?.id || (await postar("/materiais/create_cor", { "cor_material[nome]": "Branco" }), (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco").id);
    await postar("/materiais", {
      "movimento_estoque[client_uuid]": ids.cliente, "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupo,
      "movimento_estoque[cor_material_uuid]": cor, "movimento_estoque[largura]": "1.50", "movimento_estoque[gramatura]": "120g", "movimento_estoque[quantidade]": "40",
    });
    ids.tecido = (await buscarJson(`/materiais/search?tipo=tecido&q=${nomes.grupo}`))[0]?.id;

    fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "01.tif"), original);
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "corrida");
    await uploadFileAndWait(page, original);
    await page.selectOption('[data-upload-target="tipo"]', "calcado");
    ids.corrida = (await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).getAttribute("id")).replace(/^arquivo_/, "");
    if (!(await postar(`/arquivos/${ids.corrida}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error("Couldn't give the corrida its client");

    ids.primeiro = await pedidoConfirmado();
    ids.segundo = await pedidoConfirmado();
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
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
