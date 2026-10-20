// Etapa 2.7c (decided 19/10/2026): a tecido pedido's production. A corrida's
// TIFF is compacted for the RIP as soon as it is uploaded (spot channels and
// their names kept). Confirmed, the pedido has an Impressão (the paper) and
// a Calandra (onto the fabric, only after the line's paper), both in meters
// against the item's; the Impressão page gives each item's file for the
// RIP, the meters and the width in its name, alone or zipped. On a phone
// each line is a block.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText, waitForQueuedTask } = require("./support/wait");

runSpec("Produção do tecido E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { corrida: `corridaprod${U}`, cliente: `Malharia Producao ${U}`, grupo: `Helanca${U}` };
  const ids = {};
  // Outside the repo: an "e2e-" prefix would be read as part of the name.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "producao-tecido-"));
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

  function cartao(nome) {
    return page.locator(".stamp-card").filter({ hasText: nome });
  }

  function linha() {
    return page.locator(`.producao-tecido-linha[data-arte*="${nomes.corrida}"]`);
  }

  function spots(arquivo) {
    return execFileSync("exiftool", ["-s3", "-AlphaChannelsNames", arquivo]).toString().trim();
  }

  async function andamento() {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    return (await page.locator(".pedido-andamento li").evaluateAll((lis) => lis.map((li) => li.innerText.replace(/\s+/g, " ").trim()))).join();
  }

  // Each stage by goto: a Turbo visit shows the cached page first, and a
  // click on that preview is lost when the real one replaces it.
  async function irPara(etapa) {
    const href = await page.locator(`.etapas-nav-link[data-etapa='${etapa}']`).getAttribute("href");
    if (href !== `/pedidos/${ids.pedido}/tecido/producao/${etapa}`) throw new Error(`The ${etapa} tab points at ${href}`);
    await page.goto(`${BASE_URL}${href}`);
  }

  async function darBaixa(baixa, medida) {
    await baixa.locator(".baixa-abrir").click();
    await baixa.locator(".baixa-medida").fill(medida);
    await baixa.locator(".baixa-salvar").click();
  }

  async function salvoERecarregado(acao) {
    await Promise.all([page.waitForResponse((r) => new URL(r.url()).pathname === `/pedidos/${ids.pedido}/baixas` && r.status() === 200), acao()]);
    await page.getByText(/^Baixa de .* registrada/).waitFor();
  }

  await test("Setup: the print price, a client's fabric and his corrida — a TIFF with two spot channels", async () => {
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
    ids.corrida = (await cartao(nomes.corrida).getAttribute("id")).replace(/^arquivo_/, "");
    if (!(await postar(`/arquivos/${ids.corrida}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error("Couldn't give the corrida its client");
  });

  await test("Ordered and confirmed, the pedido goes through Impressão and Calandra", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    await cartao(nomes.corrida).locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.locator(".add-to-order-metros").fill("12,5");
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    ids.pedido = (await resposta.json()).pedido_uuid;
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await page.locator(".pedido-tecido-material").selectOption(ids.tecido);
    await page.locator(".pedido-pendencia--sem_material").waitFor({ state: "detached", timeout: 10000 });
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
    const progresso = await andamento();
    if (progresso !== "Impressão 0/1,Calandra 0/1") throw new Error(`Progress: ${progresso}`);
    await page.click(".pedido-ir-impressao");
    await page.waitForURL(`**/pedidos/${ids.pedido}/tecido/producao/impressao`);
    const celulas = await linha().locator("td[data-rotulo]").evaluateAll((tds) => tds.slice(0, 3).map((td) => td.innerText.trim()));
    if (celulas.slice(1).join("|") !== "1,5 m|12,5 m" || !celulas[0].includes(nomes.grupo)) throw new Error(`The line shows ${celulas.join(" | ")}`);
  });

  await test("The file for the RIP is the compacted copy, spots named, the meters and width in its name; every one zipped", async () => {
    // Compacted at upload: by now ready (or a moment away).
    await waitForQueuedTask(page, `/pedidos/${ids.pedido}/tecido/compactados`);
    await page.reload();
    const [arquivo] = await Promise.all([page.waitForEvent("download"), linha().locator(".producao-tecido-arquivo").click()]);
    if (!new RegExp(`${nomes.corrida}_12,5m_1500mm\\.tif$`).test(arquivo.suggestedFilename())) throw new Error(`File named ${arquivo.suggestedFilename()}`);
    const salvo = path.join(pasta, "rip.tif");
    await arquivo.saveAs(salvo);
    if (fs.statSync(salvo).size >= fs.statSync(original).size) throw new Error(`Not compacted: ${fs.statSync(salvo).size} bytes from ${fs.statSync(original).size}`);
    if (spots(salvo) !== "Spot_1, Spot_2") throw new Error(`The compacted file's spots: "${spots(salvo)}"`);
    const [zip] = await Promise.all([page.waitForEvent("download"), page.click(".impressao-zip")]);
    if (zip.suggestedFilename() !== `Impressao ${ids.pedido.slice(0, 8)}.zip`) throw new Error(`Zip named ${zip.suggestedFilename()}`);
  });

  await test("The Calandra waits for the paper; the Impressão's baixa is in meters, warned outside the band", async () => {
    await irPara("calandra");
    await linha().locator(".baixa-aguardando", { hasText: "aguardando Impressão" }).waitFor();
    await irPara("impressao");
    const baixa = linha().locator(".baixa");
    await darBaixa(baixa, "9");
    await baixa.locator(".baixa-aviso", { hasText: "você informou 9 m" }).waitFor();
    await baixa.locator(".baixa-medida").fill("12,5");
    await salvoERecarregado(() => baixa.locator(".baixa-salvar").click());
    await linha().locator(".baixa-feita", { hasText: "✓ 12,50 m" }).waitFor();
  });

  await test("Printed, the line goes through the Calandra", async () => {
    await irPara("calandra");
    await darBaixa(linha().locator(".baixa"), "12,5");
    await page.getByText(/^Baixa de Calandra registrada/).waitFor();
    await linha().locator(".baixa-feita", { hasText: "✓ 12,50 m" }).waitFor();
    const progresso = await andamento();
    if (progresso !== "Impressão 1/1,Calandra 1/1") throw new Error(`Progress: ${progresso}`);
  });

  await test("On a phone each line is a block, the page and its menu no wider than the screen", async () => {
    // Headed runs have no fixed viewport (null): come back to a desktop one.
    const antes = page.viewportSize() || { width: 1280, height: 720 };
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/tecido/producao/impressao`);
    await page.setViewportSize({ width: 390, height: 844 });
    try {
      const bloco = await linha().evaluate((tr) => ({
        display: getComputedStyle(tr).display,
        rotulo: getComputedStyle(tr.querySelector(".etapa-situacao"), "::before").content,
      }));
      if (bloco.display !== "grid" || bloco.rotulo !== '"Impressão"') throw new Error(`The line on a phone: ${JSON.stringify(bloco)}`);
      const direita = await page.locator(".producao-tecido-tabela").evaluate((t) => Math.max(...[...t.querySelectorAll("*")].map((e) => e.getBoundingClientRect().right)));
      if (direita > 390) throw new Error(`The table reaches ${direita}px on a 390px phone`);
      // The header's menu scrolls in its own row (it made every page 1202 px wide, 19/10/2026).
      const pagina = await page.evaluate(() => ({ largura: document.documentElement.scrollWidth, menu: getComputedStyle(document.querySelector(".header-nav")).overflowX }));
      if (pagina.largura > 390 || pagina.menu !== "auto") throw new Error(`The page on a phone: ${JSON.stringify(pagina)}`);
      await page.locator(".header-nav a", { hasText: "Parâmetros" }).scrollIntoViewIfNeeded();
      if (!(await page.locator(".header-nav a", { hasText: "Parâmetros" }).isVisible())) throw new Error("The menu's last link can't be reached on a phone");
      if (!(await linha().locator(".baixa-abrir, .baixa-feita").first().isVisible())) throw new Error("The baixa is out of sight on a phone");
    } finally {
      await page.setViewportSize(antes);
    }
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
