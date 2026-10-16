// Etapa 2.6b2 (decided 15/10/2026): a DTF pedido's production. On the roll
// it has only the Impressão; delivered cut, the Corte too. Confirmed, its
// Impressão page lists a line per etiqueta × size with its fit, and each
// line's file for the RIP — the turned size turned 90° in the background,
// the units in the name — alone or zipped. The Impressão's baixa is in
// meters of film (warned outside the dono's band), the Corte's in units,
// only after printing. On a phone each size is a block. A size turns only
// when the team marks its etiqueta (decided 16/10/2026): one too wide to go
// standing is a pendência until marked on the arte's page.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText, waitForQueuedTask } = require("./support/wait");

runSpec("Produção DTF E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  // "Em pé" 50 × 15 mm: 11 a row, 40 → 4 rows of 11 = 44 printed.
  // "Girada" 600 × 30 mm (72 dpi): wider than the film's 570 standing, 18 across turned.
  const nomes = { cliente: `Cliente Producao ${U}`, empe: `PDE${U}`, girada: `PDG${U}` };
  const ids = {};
  // Outside the repo: an "e2e-" prefix would be read as part of the name.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "producao-dtf-"));

  async function postar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  function cartao(nome) {
    return page.locator(".stamp-card").filter({ hasText: nome });
  }

  function linha(tamanho) {
    return page.locator(`.producao-dtf-etiqueta[data-arte*="${tamanho === "empe" ? nomes.empe : nomes.girada}"] .producao-dtf-linha`);
  }

  // One etiqueta of the client, of one size, in the pedido.
  async function etiqueta(nome, largura, altura, quantidade, dpi = 300) {
    const arquivo = path.join(pasta, `9-${nome} - P.tif`);
    execFileSync("convert", ["-size", `${largura}x${altura}`, "xc:#36c", "-units", "PixelsPerInch", "-density", String(dpi), arquivo]);
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "dtf");
    await uploadFileAndWait(page, arquivo);
    await page.selectOption('[data-upload-target="tipo"]', "calcado");
    const uuid = (await cartao(nome).getAttribute("id")).replace(/^arquivo_/, "");
    if (!(await postar(`/arquivos/${uuid}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error(`Couldn't give ${nome} its client`);
    await page.goto(`${BASE_URL}/arquivos`);
    await cartao(nome).locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.locator('.add-to-order-grade-input[data-tamanho-nome="P"]').fill(String(quantidade));
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    ids.pedido = (await resposta.json()).pedido_uuid;
  }

  async function darBaixa(baixa, medida) {
    // Closed until asked: the field once showed open beside every button.
    if (await baixa.locator(".baixa-editor").isVisible()) throw new Error("The baixa's field is open before clicking Baixa");
    await baixa.locator(".baixa-abrir").click();
    await baixa.locator(".baixa-medida").fill(medida);
    await baixa.locator(".baixa-salvar").click();
  }

  async function salvoERecarregado(acao) {
    await Promise.all([page.waitForResponse((r) => new URL(r.url()).pathname === `/pedidos/${ids.pedido}/baixas` && r.status() === 200), acao()]);
    await page.getByText(/^Baixa de .* registrada/).waitFor();
  }

  await test("Setup: the DTF's prices, a client and two etiquetas of his in one draft", async () => {
    await page.goto(`${BASE_URL}/parametros/edit`);
    await page.fill("#empresa_preco_metro_dtf", "120");
    await page.fill("#empresa_preco_corte_dtf", "0,05");
    await page.click('input[type="submit"][value="Save"]');
    await waitForText(page, "Production parameters saved.");
    if (!(await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" }))) throw new Error("Couldn't create the client");
    ids.cliente = await page.evaluate(async (nome) => (await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json()).find((c) => c.name === nome)?.id, nomes.cliente);
    await etiqueta(nomes.empe, 591, 177, 40);
    await etiqueta(nomes.girada, 1700, 85, 18, 72);
  });

  await test("A size that fits only turned waits for its etiqueta's mark, set on the arte's page", async () => {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    // Never turned behind the team's back: it says which mark is missing.
    const pendencia = page.locator(".pedido-pendencia--nao_cabe_em_pe", { hasText: "não cabe em pé no filme: marque Girar 90° na etiqueta" });
    await pendencia.waitFor();
    await pendencia.locator("a", { hasText: "abrir arte" }).click();
    await page.waitForURL(/#espacamento-dtf-section$/);
    await page.locator("#giro-dtf").check();
    await waitForText(page, "goes turned 90° on the film.");
    if (!(await page.locator("#giro-dtf").isChecked())) throw new Error("The mark wasn't kept");
    if (!/^↻ girada: 18 por fileira/.test(await page.locator(".arte-arquivo-encaixe").innerText())) throw new Error("The arte page doesn't show the turned fit first");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await page.locator(".pedido-confirmar").waitFor();
    if (await page.locator(".pedido-pendencia--nao_cabe_em_pe").count()) throw new Error("The pendência stayed after marking");
  });

  await test("On the roll there is no Corte; delivered cut there is", async () => {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    // Nothing is cut on the roll (D3): the stage doesn't exist for it.
    if (await page.locator(".pedido-ir-corte").count()) throw new Error("A pedido on the roll offers a Corte");
    await page.locator(".pedido-ir-impressao").waitFor();
    if (!(await postar(`/pedidos/${ids.pedido}/dtf`, { _method: "patch", entrega: "cortada" }))) throw new Error("Couldn't deliver it cut");
    await page.reload();
    await page.locator(".pedido-ir-corte").waitFor();
  });

  await test("Confirmed, its Impressão lists each size's fit and, once turned, its file for the RIP", async () => {
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    const andamento = await page.locator(".pedido-andamento li").evaluateAll((lis) => lis.map((li) => li.innerText.replace(/\s+/g, " ").trim()));
    if (andamento.join() !== "Impressão 0/2,Corte 0/2") throw new Error(`Progress: ${andamento.join()}`);
    await page.click(".pedido-ir-impressao");
    await page.waitForURL(`**/pedidos/${ids.pedido}/dtf/producao/impressao`);
    if ((await linha("empe").locator("[data-impressas]").innerText()) !== "44") throw new Error("The standing size doesn't print 44");
    if ((await linha("girada").locator("[data-impressas]").innerText()) !== "18") throw new Error("The turned size doesn't print 18");
    if (!(await linha("girada").locator(".pedido-dtf-girada").count())) throw new Error("The turned size isn't marked");
    await waitForQueuedTask(page, `/pedidos/${ids.pedido}/dtf/girados`);
    // The page polls the same endpoint and reloads once the copy is ready.
    await linha("girada").locator(".producao-dtf-arquivo").waitFor({ timeout: 15000 });
  });

  await test("A line's file goes turned, the units in its name; every one zipped", async () => {
    const [arquivo] = await Promise.all([page.waitForEvent("download"), linha("girada").locator(".producao-dtf-arquivo").click()]);
    if (!/_P_18un_girada\.tif$/.test(arquivo.suggestedFilename())) throw new Error(`Turned file named ${arquivo.suggestedFilename()}`);
    const salvo = path.join(pasta, "girada.tif");
    await arquivo.saveAs(salvo);
    const medidas = execFileSync("identify", ["-format", "%wx%h\\n", `${salvo}[0]`]).toString().trim();
    if (medidas !== "85x1700") throw new Error(`The turned file is ${medidas}, expected 85x1700`);
    const [empe] = await Promise.all([page.waitForEvent("download"), linha("empe").locator(".producao-dtf-arquivo").click()]);
    if (!/_P_44un\.tif$/.test(empe.suggestedFilename())) throw new Error(`Standing file named ${empe.suggestedFilename()}`);
    const [zip] = await Promise.all([page.waitForEvent("download"), page.click(".impressao-zip")]);
    if (zip.suggestedFilename() !== `Impressao ${ids.pedido.slice(0, 8)}.zip`) throw new Error(`Zip named ${zip.suggestedFilename()}`);
  });

  // Each stage by goto: a Turbo visit shows the cached page first, and a
  // click on that preview is lost when the real one replaces it.
  async function irPara(etapa) {
    const href = await page.locator(`.etapas-nav-link[data-etapa='${etapa}']`).getAttribute("href");
    if (href !== `/pedidos/${ids.pedido}/dtf/producao/${etapa}`) throw new Error(`The ${etapa} tab points at ${href}`);
    await page.goto(`${BASE_URL}${href}`);
  }

  await test("The Corte waits for printing; the etiqueta's Impressão baixa is in meters, warned outside the band", async () => {
    await irPara("corte");
    if ((await page.locator(".producao-dtf-linha .baixa-aguardando", { hasText: "aguardando Impressão" }).count()) !== 2) throw new Error("The Corte should wait for printing");
    await irPara("impressao");
    const referencia = page.locator(`.producao-dtf-etiqueta[data-arte*="${nomes.girada}"] .impressao-arte-topo .baixa`);
    await darBaixa(referencia, "9");
    await referencia.locator(".baixa-aviso", { hasText: "você informou 9 m" }).waitFor();
    const esperado = (await referencia.locator(".baixa-medida").getAttribute("placeholder")) || "";
    await referencia.locator(".baixa-medida").fill(esperado);
    await salvoERecarregado(() => referencia.locator(".baixa-salvar").click());
    await linha("girada").locator(".baixa-feita", { hasText: ` ${esperado} m` }).waitFor();
  });

  await test("The printed line is cut, in units", async () => {
    await irPara("corte");
    const baixa = linha("girada").locator(".baixa");
    await baixa.locator(".baixa-abrir").click();
    await baixa.locator(".baixa-medida").fill("18");
    await salvoERecarregado(() => baixa.locator(".baixa-salvar").click());
    await linha("girada").locator(".baixa-feita", { hasText: "✓ 18 unidades" }).waitFor();
    if (!(await linha("empe").locator(".baixa-aguardando").count())) throw new Error("The unprinted size should still wait");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    const andamento = await page.locator(".pedido-andamento li").evaluateAll((lis) => lis.map((li) => li.innerText.replace(/\s+/g, " ").trim()));
    if (andamento.join() !== "Impressão 1/2,Corte 1/2") throw new Error(`Progress: ${andamento.join()}`);
  });

  await test("On a phone each size is a block, nothing wider than its card", async () => {
    // Headed runs have no fixed viewport (null): come back to a desktop one.
    const antes = page.viewportSize() || { width: 1280, height: 720 };
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/dtf/producao/impressao`);
    await page.setViewportSize({ width: 390, height: 844 });
    try {
      const bloco = await linha("empe").evaluate((tr) => ({
        display: getComputedStyle(tr).display,
        rotulo: getComputedStyle(tr.querySelector(".etapa-situacao"), "::before").content,
      }));
      if (bloco.display !== "grid" || bloco.rotulo !== '"Impressão"') throw new Error(`The standing line on a phone: ${JSON.stringify(bloco)}`);
      const larga = await page.locator(".producao-dtf-etiqueta").first().evaluate((s) => s.scrollWidth > s.clientWidth);
      if (larga) throw new Error("The etiqueta's lines are wider than their card on a phone");
      if (!(await linha("empe").locator(".baixa-abrir").isVisible())) throw new Error("The baixa is out of sight on a phone");
    } finally {
      await page.setViewportSize(antes);
    }
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
