// Painel 1/4 (decided 04/11/2026): every pedido as a row, every stage as a
// column. Painel 2/4b: a confirmed tecido pedido of two items is in a block
// in time with its previsão — its Impressão may start and the Calandra (in
// the Estamparia column) waits; opening it outlines its path with each
// stage's time and shows the faixa, its items come in rows; a sector's tab is
// its numbered queue, Entrega still filters the grid. A baixa given
// elsewhere refreshes the page by itself, the tab, filter and faixa kept; a
// slow Calandra makes it "vão atrasar", a past delivery date late. On a phone
// the pedido column stays while the stages scroll. The turnos come from
// parametros-producao, run before; alone, this spec registers a 24 h one.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Painel E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { corrida: `corridapainel${U}`, cliente: `Malharia Painel ${U}`, grupo: `Suplex${U}` };
  const ids = {};
  // Outside the repo: an "e2e-" prefix would be read as part of the name.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "painel-"));
  const original = path.join(pasta, `${nomes.corrida}.tif`);

  async function postar(url, campos, alvo = page) {
    return alvo.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  async function buscarJson(url) {
    return page.evaluate(async (url) => (await fetch(url, { headers: { Accept: "application/json" } })).json(), url);
  }

  function pedido() {
    return page.locator(`#painel_${ids.pedido}`);
  }

  async function estado(coluna) {
    return pedido().locator(`:scope > .painel-linha [data-coluna='${coluna}']`).getAttribute("data-estado");
  }

  async function adicionar(metros) {
    await page.goto(`${BASE_URL}/arquivos`);
    await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.locator(".add-to-order-metros").fill(metros);
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    return (await resposta.json()).pedido_uuid;
  }

  await test("Setup: a client's fabric and his corrida, ordered twice and confirmed", async () => {
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

    ids.pedido = await adicionar("12,5");
    // Above the tecido's minimum (10 m, set by precos-tecido): below it is a pendência.
    if ((await adicionar("11")) !== ids.pedido) throw new Error("The second item went into another pedido");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    for (let i = 0; i < 2; i++) {
      await page.locator("select.pedido-tecido-material").nth(i).selectOption(ids.tecido);
      await page.waitForLoadState("networkidle");
    }
    await page.locator(".pedido-pendencia--sem_material").waitFor({ state: "detached", timeout: 10000 });
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
  });

  await test("Setup: a turno (when none) and the tecido's rhythms", async () => {
    await page.goto(`${BASE_URL}/parametros/turnos`);
    if (await page.getByText("No turno yet").count()) {
      const novo = "form.turno-novo";
      await page.fill(`${novo} input[name="turno[nome]"]`, "Painel 24h");
      await page.fill(`${novo} input[name="turno[inicio]"]`, "00:00");
      await page.fill(`${novo} input[name="turno[fim]"]`, "23:59");
      for (const dia of [0, 6]) await page.check(`${novo} input[name="turno[dias][]"][value="${dia}"]`);
      await page.click(`${novo} input[type="submit"][value="Add turno"]`);
      await waitForText(page, "Turno Painel 24h saved.");
    }
    await ritmo("calandra", "100");
  });

  async function ritmo(etapa, valor) {
    await page.goto(`${BASE_URL}/parametros/ritmos/edit`);
    await page.fill('input[name="ritmos[tecido][impressao][por_hora]"]', "100");
    await page.fill(`input[name="ritmos[tecido][${etapa}][por_hora]"]`, valor);
    await page.evaluate(() => { document.body.dataset.antesDeSalvar = "1" });
    await page.click('.ritmos-form button[type="submit"]');
    await page.waitForSelector("body:not([data-antes-de-salvar])");
    await waitForText(page, "Production rhythm saved.");
  }

  await test("The Painel shows it in a block in time with its previsão: Impressão may start, the Calandra waits in the Estamparia column", async () => {
    await page.goto(`${BASE_URL}/painel`);
    await pedido().waitFor();
    const bloco = await pedido().evaluate((el) => el.closest("[data-painel-target=bloco]").dataset.bloco);
    // Which one depends on the hour the suite runs: now, a later turno, a day.
    if (!/^(agora|turno:|amanha|dia:)/.test(bloco)) throw new Error(`In block ${bloco}`);
    const previsao = (await pedido().locator("[data-previsao]").innerText()).trim();
    if (!/^(hoje|amanhã|\S{3} \d\d\/\d\d) \d\d:\d\d$/.test(previsao)) throw new Error(`Previsão "${previsao}"`);
    const estados = [await estado("comercial"), await estado("impressao"), await estado("estamparia"), await estado("entrega")].join(",");
    if (estados !== "feita,pode_comecar,travada,ainda_nao") throw new Error(`Cells: ${estados}`);
    const texto = await pedido().locator(":scope > .painel-linha [data-coluna='estamparia']").innerText();
    if (!texto.includes("espera Impressão")) throw new Error(`Estamparia says ${texto}`);
  });

  await test("Opening it outlines its path, dims the others and shows the faixa", async () => {
    await pedido().locator(".painel-ped-btn").click();
    await pedido().locator(".painel-faixa").waitFor();
    const grade = await page.locator(".painel-grade").getAttribute("class");
    if (!grade.includes("painel-grade--destaque")) throw new Error("The others are not dimmed");
    const caminho = await pedido().locator(".painel-caminho [data-etapa]").evaluateAll((nos) => nos.map((n) => n.dataset.etapa).join(">"));
    if (caminho !== "impressao>calandra") throw new Error(`Path ${caminho}`);
    const tempos = await pedido().locator(".painel-caminho [data-etapa] .painel-no-tempo").allInnerTexts();
    if (tempos.length !== 2 || !tempos.every((t) => t.includes("→"))) throw new Error(`The stages' times: ${tempos.join(" | ")}`);
    const trava = await pedido().locator("[data-trava]").innerText();
    if (trava !== "Estamparia: espera Impressão") throw new Error(`Trava: ${trava}`);
    const links = await pedido().locator(".painel-links a").allInnerTexts();
    if (links.join("|") !== "Resumo do pedido|Impressão|Calandra") throw new Error(`Links: ${links.join("|")}`);
  });

  await test("Its items come in rows, each with its own Impressão", async () => {
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes(`/painel/pedidos/${ids.pedido}/itens`)),
      pedido().locator(".painel-itens-btn").click(),
    ]);
    if (!resposta.ok()) throw new Error(`Items answered ${resposta.status()}`);
    await pedido().locator(".painel-linha--item").nth(1).waitFor();
    const impressao = await pedido().locator(".painel-linha--item [data-coluna='impressao']").evaluateAll((cs) => cs.map((c) => c.dataset.estado).join(","));
    if (impressao !== "pode_comecar,pode_comecar") throw new Error(`Items' Impressão: ${impressao}`);
    await pedido().locator(".painel-itens-btn").click();
    await pedido().locator(".painel-linha--item").first().waitFor({ state: "hidden" });
  });

  function naFila(setor) {
    return page.locator(`[data-fila-setor='${setor}'] [data-fila-pedido='${ids.pedido}']`);
  }

  await test("The Impressão tab shows its numbered queue instead of the grid; the Calandra's waits; Entrega filters the grid", async () => {
    await page.locator(".painel-setor[data-setor='impressao']").click();
    await page.locator("[data-fila-setor='impressao']").waitFor();
    if (await page.locator(".painel-quadro").isVisible()) throw new Error("The grid shows with the queue");
    const posicao = (await naFila("impressao").first().locator(".painel-fila-pos").innerText()).trim();
    if (!/^\d+º$/.test(posicao)) throw new Error(`Its place in the queue: ${posicao}`);
    if (!(await naFila("impressao").first().locator(".painel-fila-hora").innerText()).match(/\d\d:\d\d–\d\d:\d\d/)) throw new Error("No time in the turno");
    if (Number(await page.locator("[data-conta='fila:impressao']").innerText()) < 1) throw new Error("The Impressão tab counts nothing");
    await page.locator(".painel-setor[data-setor='estamparia']").click();
    if (!(await naFila("estamparia").first().innerText()).includes("espera Impressão")) throw new Error("The Calandra doesn't wait for the Impressão");
    await page.locator(".painel-setor[data-setor='entrega']").click();
    await page.locator(".painel-quadro").waitFor();
    // Not ready to deliver: nothing of it is done yet.
    await pedido().waitFor({ state: "hidden" });
    await page.locator(".painel-setor[data-setor='']").click();
    await pedido().waitFor();
  });

  // Q5a: the queue changed — the page refreshes by itself, keeping the tab,
  // the filter and the opened faixa.
  await test("A baixa given elsewhere refreshes the Painel by itself, keeping the tab, the filter and the faixa", async () => {
    await page.selectOption("[data-painel-target=tipo]", "tecido");
    await pedido().locator(".painel-ped-btn").click();
    await pedido().locator(".painel-faixa").waitFor();
    await page.evaluate(() => { window.semRecarregar = true });
    const outra = await page.context().newPage();
    await outra.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await Promise.all([
      page.waitForResponse((r) => new URL(r.url()).pathname === "/painel" && r.request().method() === "GET"),
      postar(`/pedidos/${ids.pedido}/baixas`, { etapa: "impressao", nivel: "pedido", medida: "23,5", confirmar: "1" }, outra),
    ]);
    await outra.close();
    await page.locator(`#painel_${ids.pedido} > .painel-linha [data-coluna='impressao'][data-estado='feita']`).waitFor();
    if (!(await page.evaluate(() => window.semRecarregar))) throw new Error("The page reloaded");
    if (await pedido().locator(".painel-faixa").isHidden()) throw new Error("The faixa closed");
    if ((await page.locator("[data-painel-target=tipo]").inputValue()) !== "tecido") throw new Error("The filter was lost");
    if (await naFila("impressao").count()) throw new Error("Printed, it is still in the Impressão queue");
    await page.selectOption("[data-painel-target=tipo]", "");
  });

  // Q6a: the previsão falls after a deadline that hasn't passed.
  await test("A slow Calandra makes it go past today's deadline: \"vão atrasar\" counts and filters it", async () => {
    await ritmo("calandra", "0,5");
    const hoje = await page.evaluate(() => new Date().toLocaleDateString("sv-SE", { timeZone: "America/Sao_Paulo" }));
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await page.fill("#prazo_entrega", hoje);
    await page.click(".pedido-prazo-form button[type=submit]");
    await waitForText(page, "Prazo de entrega atualizado.");
    await page.goto(`${BASE_URL}/painel`);
    if ((await pedido().getAttribute("data-vai-atrasar")) !== "true") throw new Error("Not going to be late");
    const selo = (await pedido().locator(".painel-fim .painel-folga").innerText()).trim();
    if (!/^atrasa \d+ dias?$/.test(selo)) throw new Error(`The folga says "${selo}"`);
    await page.locator(".painel-cont[data-filtro='vaiAtrasar']").click();
    const visiveis = await page.locator("[data-painel-target=bloco] > .painel-pedido:not([hidden])").evaluateAll((ps) => ps.map((p) => p.dataset.uuid));
    if (visiveis.join() !== ids.pedido) throw new Error(`The "vão atrasar" filter shows ${visiveis.join()}`);
    await page.locator(".painel-cont[data-filtro='vaiAtrasar']").click();
  });

  await test("A past delivery date set on the pedido makes it late on the Painel", async () => {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await page.fill("#prazo_entrega", "2026-01-10");
    await page.click(".pedido-prazo-form button[type=submit]");
    await waitForText(page, "Prazo de entrega atualizado.");
    await page.goto(`${BASE_URL}/painel`);
    if ((await pedido().getAttribute("data-atrasado")) !== "true") throw new Error("Not late");
    if (!(await pedido().locator(".painel-fim").innerText()).includes("prazo 10/01")) throw new Error("The deadline isn't shown");
    await page.locator(".painel-cont[data-filtro='atrasado']").click();
    const visiveis = await page.locator(".painel-pedido:not([hidden])").evaluateAll((ps) => ps.map((p) => p.dataset.uuid));
    if (visiveis.join() !== ids.pedido) throw new Error(`The late filter shows ${visiveis.join()}`);
    await page.locator(".painel-cont[data-filtro='atrasado']").click();
  });

  await test("On a phone the pedido column stays while the stages scroll; the page itself doesn't", async () => {
    await page.setViewportSize({ width: 400, height: 800 });
    await page.goto(`${BASE_URL}/painel`);
    const largura = await page.evaluate(() => document.documentElement.scrollWidth);
    if (largura > 400) throw new Error(`The page scrolls sideways (${largura}px)`);
    const antes = await pedido().locator(".painel-ped").boundingBox();
    await page.locator(".painel-quadro").evaluate((q) => { q.scrollLeft = 300 });
    const depois = await pedido().locator(".painel-ped").boundingBox();
    if (Math.round(antes.x) !== Math.round(depois.x)) throw new Error(`The pedido column moved from ${antes.x} to ${depois.x}`);
    await page.setViewportSize({ width: 1280, height: 720 });
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
