const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForQueuedTask } = require("./support/wait");
const { imageHasVisiblePixels } = require("./support/pixels");
const { modeloOficial, adicionarPartes } = require("./support/catalogo");

// "Adicionar ao Pedido" lists every part of the arte's molde; checked parts
// go to production, unchecked ones are excluded. Etapa 1.2 (3/3, parte 2;
// decided 05/10/2026): the pedido reads the arte — each ordered number of a
// part finds its DXF size and the arte's file of that size, or is a
// pendência settled inside the arte ("Enviar arquivo", "Trazer de outra arte").
runSpec("Pedidos E2E: parts of the arte (add-to-order modal + pedido page)", async ({ page, test }) => {
  const UNIQ = `PP${Date.now()}`;
  const names = { lateral: `Lateral ${UNIQ}`, lingua: `Lingua ${UNIQ}` };
  const tempFiles = [];

  // Solid-color TIF named with its size (…-29_30, read as 29-30) and an e2e-
  // prefix, so bin/e2e cleans it if we abort.
  function makeArte(label, color) {
    const file = path.join(__dirname, `e2e-${label}-${UNIQ}-29_30.tif`);
    // 10 DPI: a 15 cm arte, so the expected paper (Etapa 2.2, 1/3) — which
    // needs the file's size in mm — is a real amount, not 0,00002 m.
    execSync(`convert -size 60x60 xc:${color} -units PixelsPerInch -density 10 'TIFF:${file}'`);
    tempFiles.push(file);
    return file;
  }

  async function csrf() {
    return page.evaluate(() => document.querySelector("meta[name='csrf-token']")?.content || "");
  }

  async function postForm(url, fields) {
    const token = await csrf();
    return page.evaluate(async ({ url, fields, token }) => {
      const body = new URLSearchParams({ authenticity_token: token });
      for (const [k, v] of fields) body.append(k, v);
      const r = await fetch(url, { method: "POST", body, headers: { "Content-Type": "application/x-www-form-urlencoded" } });
      return r.status;
    }, { url, fields, token });
  }

  async function findId(searchUrl, key, value) {
    return page.evaluate(async ({ searchUrl, key, value }) => {
      const rows = await (await fetch(searchUrl)).json();
      return rows.find((r) => r[key] === value)?.id;
    }, { searchUrl, key, value });
  }

  // Peças + client + molde (official modelo) with both as parts, through the app's own endpoints.
  async function setupMolde() {
    await page.goto(BASE_URL);
    for (const nome of Object.values(names)) await postForm("/pecas", [[ "peca[nome]", nome ]]);
    const pecaIds = {
      lateral: await findId(`/pecas/search?q=${encodeURIComponent(names.lateral)}`, "nome", names.lateral),
      lingua: await findId(`/pecas/search?q=${encodeURIComponent(names.lingua)}`, "nome", names.lingua),
    };
    const modeloId = (await modeloOficial(page, "Tenis")).id;
    const clientName = `Cliente ${UNIQ}`;
    await postForm("/clients", [[ "client[name]", clientName ], [ "client[responsible]", "E2E" ]]);
    const clientId = await findId(`/clients/search?q=${encodeURIComponent(clientName)}`, "name", clientName);
    const moldeNome = `Molde ${UNIQ}`;
    await postForm("/moldes", [[ "molde[sufixo]", moldeNome ], [ "molde[client_uuid]", clientId ], [ "molde[modelo_uuid]", modeloId ]]);
    const moldeId = await findId(`/moldes/search?q=${encodeURIComponent(moldeNome)}`, "sufixo", moldeNome);
    await adicionarPartes(page, moldeId, [ pecaIds.lateral, pecaIds.lingua ]);
    if (!pecaIds.lateral || !pecaIds.lingua || !modeloId || !moldeId) {
      throw new Error(`Setup failed: ${JSON.stringify({ pecaIds, modeloId, clientId, moldeId })}`);
    }
    return { pecaIds, moldeId, modeloId, clientId };
  }

  // The part's DXF, organized as Par with one size (29-30), linked to the molde.
  async function corteOrganizado(label, pecaId) {
    const dxf = path.join(__dirname, `e2e-dxf-${label}-${UNIQ}.dxf`);
    fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "29-30.dxf"), dxf);
    tempFiles.push(dxf);
    await page.goto(BASE_URL);
    await uploadFileAndWait(page, dxf);
    const uuid = (await page.locator(".stamp-card").filter({ hasText: `e2e-dxf-${label}-${UNIQ}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
    const organizado = await postForm(`/arquivos/${uuid}/organize`, [[ "_method", "patch" ], [ "modelo_uuid", molde.modeloId ], [ "peca_uuid", pecaId ],
      [ "tipo_grade", "par" ], [ "tamanhos[0][tamanhos]", "30" ], [ "tamanhos[0][width_mm]", "150" ], [ "tamanhos[0][height_mm]", "250" ], [ "tamanhos[0][area_mm2]", "8000" ]]);
    const ligado = await postForm(`/arquivos/${uuid}/add_molde`, [[ "molde_uuid", molde.moldeId ]]);
    if (organizado >= 400 || ligado >= 400) throw new Error(`DXF ${label}: organize HTTP ${organizado}, add_molde HTTP ${ligado}`);
    await waitForQueuedTask(page, `/arquivos/${uuid}/preparacao_tamanhos.json`);
    return uuid;
  }

  function cardFor(file) {
    return page.locator(".stamp-card").filter({ hasText: path.basename(file, ".tif") }).first();
  }

  // Uploads the arte file and links it to the molde + peça (update_molde).
  async function uploadArte(file, moldeId, pecaId) {
    await page.goto(BASE_URL);
    await uploadFileAndWait(page, file);
    const href = await cardFor(file).locator("a").first().getAttribute("href");
    const uuid = href.split("/").pop();
    if (moldeId) {
      const fields = [[ "_method", "patch" ], [ "molde_uuid", moldeId ]];
      if (pecaId) fields.push([ "peca_uuid", pecaId ]);
      const status = await postForm(`/arquivos/${uuid}/update_molde`, fields);
      if (status >= 400) throw new Error(`update_molde failed for ${uuid}: HTTP ${status}`);
      await waitForQueuedTask(page, `/arquivos/${uuid}/busca_tamanho.json`);
    }
    return uuid;
  }

  async function openModalFor(file) {
    await page.goto(BASE_URL);
    await cardFor(file).locator(".btn-add-to-order").click({ force: true });
    await page.locator(".add-to-order-dialog[open]").waitFor({ timeout: 5000 });
  }

  function pecaCard(nome) {
    return page.locator(".add-to-order-peca").filter({ hasText: nome });
  }

  // Waits out the CSS opacity transition instead of reading a mid-fade value.
  // state: "dimmed" (opacity < 0.5, unchecked) or "visible" (opacity 1).
  async function waitForOpacity(locator, state) {
    const nome = (await locator.locator(".pedido-peca-nome, .add-to-order-peca-nome").first().innerText().catch(() => "")).trim();
    const handle = await locator.elementHandle();
    try {
      await page.waitForFunction(({ el, state }) => {
        const opacity = parseFloat(getComputedStyle(el).opacity);
        return state === "dimmed" ? opacity < 0.5 : opacity === 1;
      }, { el: handle, state }, { timeout: 3000 });
    } catch {
      const opacity = await handle.evaluate((el) => getComputedStyle(el).opacity);
      throw new Error(`${nome} should be ${state}; opacity stayed at ${opacity}`);
    }
  }

  // Etapa 1.2 (3/3): the grade is by number; one pair of the 30 (Par 29-30).
  async function pedirUmPar() {
    await page.locator('.add-to-order-grade-input[data-tamanho-nome="30"]').fill("1");
  }

  // Submits the open modal and returns the pedido uuid from adicionar_item.
  async function submitModal() {
    await pedirUmPar();
    const responsePromise = page.waitForResponse((r) => r.url().endsWith("/pedidos/adicionar_item"));
    await page.locator("[data-add-to-order-target='submitBtn']").click();
    const json = await (await responsePromise).json();
    if (!json.ok) throw new Error(`adicionar_item failed: ${json.error}`);
    return json.pedido_uuid;
  }

  // A part's label in the matrix of the itemIndex-th item (creation order).
  function pedidoPeca(itemIndex, nome) {
    return page.locator(".pedido-item").nth(itemIndex).locator(".pedido-peca").filter({ has: page.locator(".pedido-peca-nome", { hasText: nome }) });
  }

  // The matrix cell of a part × number (Etapa 1.2, 3/3 parte 3a).
  async function celula(itemIndex, nome, numero) {
    const uuid = await pedidoPeca(itemIndex, nome).getAttribute("data-peca-uuid");
    return page.locator(".pedido-item").nth(itemIndex).locator(`.pedido-parte-numero[data-peca-uuid="${uuid}"][data-numero="${numero}"]`);
  }

  // The cell's state and the file it links to (title = file name).
  async function expectCelula(cell, estado, filename) {
    const atual = await cell.getAttribute("data-estado");
    if (atual !== estado) throw new Error(`Expected ${estado}, got ${atual} ("${(await cell.innerText()).trim()}")`);
    if (filename && (await cell.locator("a").getAttribute("title")) !== filename) throw new Error(`Cell should link to ${filename}`);
  }

  function pendencia(texto) {
    return page.locator(".pedido-painel .pedido-pendencia").filter({ hasText: texto });
  }

  // Clicks a part checkbox on the pedido page, waits for the save and for the
  // page refresh it triggers (the side panel recounts).
  async function togglePedidoPeca(card, checked) {
    const saved = page.waitForResponse((r) => r.url().includes("/alternar_peca"));
    const refreshed = page.waitForResponse((r) => r.request().method() === "GET" && new URL(r.url()).pathname === `/pedidos/${pedidoUuid}`);
    await (checked ? card.locator(".pedido-peca-check").check() : card.locator(".pedido-peca-check").uncheck());
    const json = await (await saved).json();
    if (!json.ok) throw new Error(`alternar_peca failed: ${json.error}`);
    await refreshed;
  }

  async function expectPedidoPeca(card, estado, checked) {
    const cls = await card.getAttribute("class");
    if (!cls.includes(`pedido-peca--${estado}`)) throw new Error(`Expected ${estado}, got class "${cls}"`);
    if (checked !== undefined && (await card.locator(".pedido-peca-check").isChecked()) !== checked) {
      throw new Error(`Checkbox should be ${checked ? "checked" : "unchecked"} (${estado})`);
    }
  }

  // The pedido's Corte page (Etapa 1.2, 3/3 parte 3b): the line of a part.
  async function abrirCorte() {
    await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/corte`);
  }

  function linhaDoCorte(nome) {
    return page.locator(`tr.corte-linha[data-peca="${nome}"]`);
  }

  // The pieces of a Corte line ("4 peças 2 direito · 2 esquerdo"), without
  // the expected metragem shown under them (Etapa 2.2, 1/3).
  async function pecasDoCorte(nome) {
    const partes = await linhaDoCorte(nome).locator(".corte-total strong, .corte-total .corte-conta:not(.corte-metros)").allInnerTexts();
    return partes.join(" ").replace(/\s+/g, " ").trim();
  }

  // A molde part's pieces per pair / mirrored, saved from the molde page.
  async function configurarParte(nome, { pecasPorPar, espelhada }) {
    await page.goto(`${BASE_URL}/moldes/${molde.moldeId}`);
    const form = page.locator(`.molde-peca-row[data-parte="${nome}"] form.molde-peca-pecas`);
    await form.locator('input[name="pecas_por_par"]').fill(String(pecasPorPar));
    await (espelhada ? form.locator('input[type=checkbox][name="espelhada"]').check() : form.locator('input[type=checkbox][name="espelhada"]').uncheck());
    await Promise.all([ page.waitForURL(`**/moldes/${molde.moldeId}`), form.locator('button[type="submit"]').click() ]);
    await page.getByText("Piece configuration updated.").waitFor();
  }

  let molde;
  let pedidoUuid;
  const cortes = {};
  const lateralFile = makeArte("lateral", "red");
  const linguaFile = makeArte("lingua", "blue");
  const loneFile = makeArte("lone", "green");
  const terceiroFile = makeArte("terceiro", "purple");
  const uploadFile = makeArte("upload", "teal");
  const direitoFile = makeArte("direito", "orange");

  try {
    await test("Setup: molde with Lateral + Língua, each with its organized DXF, and a Lateral arte of 29-30", async () => {
      molde = await setupMolde();
      cortes.lateral = await corteOrganizado("lateral", molde.pecaIds.lateral);
      await corteOrganizado("lingua", molde.pecaIds.lingua);
      await uploadArte(lateralFile, molde.moldeId, molde.pecaIds.lateral);
    });

    await test("Modal lists both parts; the one this arte has no file for is pending, without checkbox", async () => {
      await openModalFor(lateralFile);
      await pecaCard(names.lingua).waitFor({ timeout: 5000 });
      const count = await page.locator(".add-to-order-peca").count();
      if (count !== 2) throw new Error(`Expected 2 parts, got ${count}`);
      if ((await pecaCard(names.lateral).locator(".add-to-order-peca-check").count()) !== 1) throw new Error("Lateral should have a checkbox");
      const pending = pecaCard(names.lingua);
      if (!(await pending.getAttribute("class")).includes("add-to-order-peca--pendente")) throw new Error("Língua should be pending");
      if ((await pending.locator(".add-to-order-peca-check").count()) !== 0) throw new Error("Pending part must not have a checkbox");
    });

    await test("The part preview loads with visible pixels", async () => {
      const src = await pecaCard(names.lateral).locator("img.add-to-order-peca-thumb").getAttribute("src");
      if (!src || !src.includes("/preview")) throw new Error(`Preview src missing: ${src}`);
      if (!(await imageHasVisiblePixels(page, src))) throw new Error("Part preview has no visible pixels");
    });

    await test("Cancel closes the modal and clears the parts", async () => {
      await page.locator(".add-to-order-footer .btn-secondary").click();
      if (await page.locator(".add-to-order-dialog[open]").count()) throw new Error("Modal still open after Cancel");
      if (await page.locator(".add-to-order-peca").count()) throw new Error("Parts not cleared after Cancel");
    });

    await test("Added: the Lateral 30 comes from its file; the Língua 30 is a pendência with Enviar / Trazer", async () => {
      await openModalFor(lateralFile);
      await pecaCard(names.lingua).waitFor({ timeout: 5000 });
      pedidoUuid = await submitModal();
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await expectPedidoPeca(pedidoPeca(0, names.lateral), "incluida", true);
      await expectCelula(await celula(0, names.lateral, "30"), "producao", path.basename(lateralFile, ".tif"));
      if ((await (await celula(0, names.lateral, "30")).innerText()).trim() !== "29-30 ✓") throw new Error("Lateral 30 should read 29-30 ✓");
      await expectPedidoPeca(pedidoPeca(0, names.lingua), "pendente");
      await expectCelula(await celula(0, names.lingua, "30"), "sem_arquivo");
      const pendente = pendencia(`${names.lingua} 29-30 (30×1) sem arquivo de produção`);
      if ((await pendente.locator("form.pedido-parte-enviar").count()) !== 1 || (await pendente.locator("a.pedido-parte-trazer").count()) !== 1) throw new Error("Enviar / Trazer missing");
    });

    await test("A pendência is listed and Confirmar is disabled; the list shows a badge; the server refuses", async () => {
      if ((await page.locator(".pedido-pendencias h3").innerText()).trim() !== "Falta para confirmar (1)") throw new Error("Pendência count missing");
      if (!(await page.locator(`form[action$="/pedidos/${pedidoUuid}/confirmar"] button`).isDisabled())) throw new Error("Confirmar should be disabled");
      await page.goto(`${BASE_URL}/pedidos`);
      const row = page.locator("tr").filter({ has: page.locator(`a[href="/pedidos/${pedidoUuid}"]`) });
      if (!/1 pendente/.test(await row.locator(".pedido-pendentes-badge").innerText())) throw new Error("Pending badge missing");
      const token = await csrf();
      await page.evaluate(async ({ uuid, token }) => {
        await fetch(`/pedidos/${uuid}/confirmar`, { method: "POST", headers: { "X-CSRF-Token": token } });
      }, { uuid: pedidoUuid, token });
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      if ((await page.locator("h2 .badge").innerText()).trim() !== "rascunho") throw new Error("Pedido should stay rascunho");
    });

    await test("'Trazer de outra arte' opens the arte with the section open; bringing the Língua settles the pendência", async () => {
      await uploadArte(linguaFile, molde.moldeId, molde.pecaIds.lingua);
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}\?trazer=1/), pendencia(names.lingua).locator("a.pedido-parte-trazer").click() ]);
      if (!(await page.locator("details.arte-juntar").evaluate((d) => d.open))) throw new Error("The 'bring other artes' section should be open");
      await page.locator(".arte-candidata--card").filter({ hasText: path.basename(linguaFile, ".tif") }).click();
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), page.locator('.arte-juntar-form button[type="submit"]').click() ]);

      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await expectPedidoPeca(pedidoPeca(0, names.lingua), "incluida", true);
      await expectCelula(await celula(0, names.lingua, "30"), "producao", path.basename(linguaFile, ".tif"));
      if (await page.locator(".pedido-pendencias").count()) throw new Error("No pendência should be left");
      if (await page.locator(`form[action$="/pedidos/${pedidoUuid}/confirmar"] button`).isDisabled()) throw new Error("Confirmar should be enabled");
    });

    await test("Unchecking a part in the modal is sent as excluded", async () => {
      await openModalFor(lateralFile);
      const lingua = pecaCard(names.lingua);
      await lingua.locator(".add-to-order-peca-check").waitFor({ timeout: 5000 });
      await lingua.locator(".add-to-order-peca-check").uncheck();
      await pedirUmPar();
      const responsePromise = page.waitForResponse((r) => r.url().endsWith("/pedidos/adicionar_item"));
      await page.locator("[data-add-to-order-target='submitBtn']").click();
      if (!(await (await responsePromise).json()).ok) throw new Error("adicionar_item failed");
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await expectPedidoPeca(pedidoPeca(1, names.lateral), "incluida", true);
      await expectPedidoPeca(pedidoPeca(1, names.lingua), "excluida", false);
      await waitForOpacity(pedidoPeca(1, names.lingua), "dimmed");
    });

    await test("Checking and unchecking a part on the pedido page saves it (survives reload)", async () => {
      await togglePedidoPeca(pedidoPeca(1, names.lingua), true);
      await waitForOpacity(pedidoPeca(1, names.lingua), "visible");
      await togglePedidoPeca(pedidoPeca(1, names.lateral), false);
      await page.reload();
      await expectPedidoPeca(pedidoPeca(1, names.lingua), "incluida", true);
      await expectPedidoPeca(pedidoPeca(1, names.lateral), "excluida", false);
    });

    // State here: item 0 = Lateral + Língua checked; item 1 = Lateral unchecked
    // + Língua checked. Each asks one 30 (DXF 29-30).
    await test("Corte lists only checked parts per DXF size, in pieces (2 per pair)", async () => {
      await abrirCorte();
      const lateral = await pecasDoCorte(names.lateral);
      const lingua = await pecasDoCorte(names.lingua);
      if (lateral !== "2 peças 1 par × 2" || lingua !== "4 peças 2 pares × 2") throw new Error(`Lines: Lateral "${lateral}", Língua "${lingua}"`);
      if ((await linhaDoCorte(names.lateral).getAttribute("data-tamanho")) !== "29-30") throw new Error("Lateral should be cut in its DXF 29-30");
    });

    await test("Unchecking a part on the pedido takes it off the Corte page", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await togglePedidoPeca(pedidoPeca(0, names.lateral), false);
      await abrirCorte();
      if (await linhaDoCorte(names.lateral).count()) throw new Error("Lateral still on the Corte page after unchecking");
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await togglePedidoPeca(pedidoPeca(0, names.lateral), true);
    });

    // Decided 06/10/2026: each molde part says how many pieces a pair takes
    // and whether they are mirrored; a "não corta" part never reaches the table.
    await test("The molde's pieces per pair and 'espelhada' change the Corte page; 'não corta' leaves it", async () => {
      await configurarParte(names.lateral, { pecasPorPar: 4, espelhada: true });
      await abrirCorte();
      const lateral = await pecasDoCorte(names.lateral);
      if (lateral !== "4 peças 2 direito · 2 esquerdo") throw new Error(`Lateral line: "${lateral}"`);

      // The "Cortar / Não corta" switch saves and reloads the molde page.
      const alternarCorte = async () => {
        await page.goto(`${BASE_URL}/moldes/${molde.moldeId}`);
        await Promise.all([ page.waitForEvent("load"), page.locator(`.molde-peca-row[data-parte="${names.lingua}"] .toggle-slider`).click() ]);
      };
      await alternarCorte();
      if ((await page.locator(`.molde-peca-row[data-parte="${names.lingua}"] .toggle-label`).innerText()).trim() !== "Não corta") throw new Error("Língua should be 'Não corta'");
      await abrirCorte();
      if (await linhaDoCorte(names.lingua).count()) throw new Error("A 'não corta' part should not be on the Corte page");

      await alternarCorte();
      await configurarParte(names.lateral, { pecasPorPar: 2, espelhada: false });
    });

    await test("An odd number of pieces on a mirrored part is refused, saying why", async () => {
      await page.goto(`${BASE_URL}/moldes/${molde.moldeId}`);
      const form = page.locator(`.molde-peca-row[data-parte="${names.lateral}"] form.molde-peca-pecas`);
      await form.locator('input[name="pecas_por_par"]').fill("3");
      await form.locator('input[type=checkbox][name="espelhada"]').check();
      await Promise.all([ page.waitForURL(`**/moldes/${molde.moldeId}`), form.locator('button[type="submit"]').click() ]);
      await page.getByText("needs an even number of pieces per pair").waitFor();
      if ((await form.locator('input[name="pecas_por_par"]').inputValue()) !== "2") throw new Error("The refused value should not be saved");
    });

    await test("'Enviar arquivo' on a pendência uploads into the arte, with the part and size, and settles it", async () => {
      await uploadArte(terceiroFile, molde.moldeId, molde.pecaIds.lateral);
      await openModalFor(terceiroFile);
      await pecaCard(names.lingua).waitFor({ timeout: 5000 });
      await submitModal();
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await expectPedidoPeca(pedidoPeca(2, names.lingua), "pendente");
      // Items 0 and 1 are settled by now: this is the only pendência.
      const pending = pendencia(names.lingua);
      await Promise.all([
        page.waitForURL(`**/pedidos/${pedidoUuid}/resumo`, { timeout: 30000 }),
        pending.locator("form.pedido-parte-enviar input[type=file]").setInputFiles(uploadFile),
      ]);
      await page.getByText("added to this arte (29-30)").waitFor();
      await expectPedidoPeca(pedidoPeca(2, names.lingua), "incluida");
      await expectCelula(await celula(2, names.lingua, "30"), "producao", path.basename(uploadFile, ".tif"));
      // Processing is queued: the part's "processando…" reloads the page once
      // it is done; then the file's preview has pixels.
      await pedidoPeca(2, names.lingua).locator(".pedido-peca-processando").waitFor({ state: "detached", timeout: 45000 });
      const href = await (await celula(2, names.lingua, "30")).locator("a").getAttribute("href");
      if (!(await imageHasVisiblePixels(page, `${href}/preview`))) throw new Error("Uploaded file preview has no visible pixels");
    });

    // Etapa 1.2 (3/3, parte 3c, decided 06/10/2026): the printer's page, per
    // arte, one line per file, in pieces. Item 0 asks one 30 of Lateral +
    // Língua (2 pieces each); item 1 the same arte, Lateral unchecked.
    await test("Impressão lists per arte each file to print, in pieces; the zip has the artes", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await Promise.all([ page.waitForURL(`**/pedidos/${pedidoUuid}/impressao`), page.locator("a.pedido-ir-impressao").click() ]);
      const primeira = page.locator(".impressao-arte").first();
      const lateral = (await primeira.locator(`tr.impressao-linha[data-peca="${names.lateral}"] .corte-total strong`).innerText()).trim();
      const lingua = (await primeira.locator(`tr.impressao-linha[data-peca="${names.lingua}"] .corte-total strong`).innerText()).trim();
      if (lateral !== "2 peças" || lingua !== "2 peças") throw new Error(`Lines: Lateral ${lateral}, Língua ${lingua}`);
      const [arte] = await Promise.all([ page.waitForEvent("download"), primeira.locator("a.impressao-baixar").first().click() ]);
      if (!arte.suggestedFilename().endsWith(".tif")) throw new Error(`Unexpected arte download: ${arte.suggestedFilename()}`);
      const [zip] = await Promise.all([ page.waitForEvent("download", { timeout: 30000 }), page.locator("a.impressao-zip").click() ]);
      const bytes = fs.readFileSync(await zip.path());
      if (bytes.subarray(0, 2).toString() !== "PK" || !bytes.includes(Buffer.from("_29-30.tif"))) throw new Error("The zip should hold the artes under their full names");
    });

    // Etapa 2.2 (1/3, decided 07/10/2026): the expected metragem comes from
    // the files — the arte's rectangle on the paper's width (a parameter of the
    // dono). The items have no material, so the Corte can't expect fabric yet.
    await test("Impressão expects paper from the arte's size and the dono's paper width; the Corte needs the material", async () => {
      const metros = async () => {
        await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/impressao`);
        return Number(await page.locator(".impressao-arte").first().locator(`tr.impressao-linha[data-peca="${names.lateral}"] .corte-metros`).getAttribute("data-metros"));
      };
      const larguraPadrao = await metros();
      if (!(larguraPadrao > 0)) throw new Error(`Expected paper on the default width, got ${larguraPadrao}`);

      const salvar = async (largura) => {
        await page.goto(`${BASE_URL}/parametros/edit`);
        await page.fill('input[name="empresa[largura_papel_mm]"]', String(largura));
        await Promise.all([ page.waitForURL("**/parametros/edit"), page.click('input[type="submit"][value="Save"]') ]);
        await page.getByText("Production parameters saved.").waitFor();
      };
      // A narrower roll fits fewer pieces across: more paper per piece
      // (200 mm: one 15 cm arte across instead of ten).
      await salvar(200);
      const estreito = await metros();
      await salvar(1600);
      if (!(estreito > larguraPadrao)) throw new Error(`A 200 mm roll should take more paper: ${estreito} vs ${larguraPadrao}`);

      // The arte page shows the same: how much paper one piece of each file
      // takes (a 15,24 cm arte: ten across 1,60 m, 15,24 mm of paper each).
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await page.goto(`${BASE_URL}${await (await celula(0, names.lateral, "30")).locator("a").getAttribute("href")}`);
      const consumo = (await page.locator(".arte-arquivo--atual .arte-arquivo-consumo").innerText()).trim();
      if (!/^65,6 por metro · 1,52% do metro$/.test(consumo)) throw new Error(`Paper per piece on the arte page: "${consumo}"`);

      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/corte`);
      const corte = (await linhaDoCorte(names.lateral).first().locator(".corte-metros").innerText()).trim();
      if (corte !== "sem material: sem metragem") throw new Error(`Corte without material: "${corte}"`);
    });

    // Etapa 2.2 (1/3, decided 08/10/2026): each corte says how its pieces may
    // turn in the fit that gives its consumption. No default — whoever
    // uploads it marks it; until then the page and the card warn, and the
    // sizes have no consumption.
    await test("The corte page sets how its pieces may turn in the fit: não pode girar | 180° | 90°", async () => {
      await page.goto(`${BASE_URL}/arquivos/${cortes.lateral}`);
      const marcado = () => page.locator(".giro-corte input[name=giro_no_encaixe]:checked").count();
      if ((await marcado()) !== 0) throw new Error("A corte starts with no turn marked");
      await page.locator(".giro-corte-pendente", { hasText: "Giro não marcado" }).waitFor();
      const semGiro = (await page.locator(".tamanho-list--readonly .tamanho-consumo").first().innerText()).trim();
      if (semGiro !== "giro não marcado: sem consumo") throw new Error(`Size consumption without a turn: "${semGiro}"`);
      await Promise.all([ page.waitForURL(`**/arquivos/${cortes.lateral}`), page.locator('.giro-corte label:has-text("90°")').click() ]);
      await page.getByText("Giro no encaixe: 90°.").waitFor();
      await page.reload();
      if ((await page.locator(".giro-corte input[name=giro_no_encaixe]:checked").getAttribute("value")) !== "90") throw new Error("The 90° choice should be saved");
      if (await page.locator(".giro-corte-pendente").count()) throw new Error("The warning should go once the turn is marked");
      await Promise.all([ page.waitForURL(`**/arquivos/${cortes.lateral}`), page.locator('.giro-corte label:has-text("180°")').click() ]);
      await page.getByText("Giro no encaixe: 180°.").waitFor();
    });

    // Decided 07/10/2026: a file without side serves both sides; once one
    // file has a side, the other side is a pendência of its own.
    await test("A mirrored part: one side's file asks for the other; 'Enviar arquivo DIR' settles it; Impressão prints each side", async () => {
      await configurarParte(names.lateral, { pecasPorPar: 2, espelhada: true });
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      const arteDaLateral = await (await celula(0, names.lateral, "30")).locator("a").getAttribute("href");
      await page.goto(`${BASE_URL}${arteDaLateral}`);
      const lado = page.locator(`.arte-arquivo[data-arquivo-uuid="${arteDaLateral.split("/").pop()}"] form.arte-lado select`);
      await Promise.all([ page.waitForURL(`**${arteDaLateral}`), lado.selectOption("esquerdo") ]);
      await page.getByText("side ESQ").waitFor();

      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await expectCelula(await celula(0, names.lateral, "30"), "sem_lado");
      const pendente = pendencia(`${names.lateral} 29-30 (30×1) sem o arquivo DIR`);
      if ((await pendente.locator(".pedido-peca-enviar-label").innerText()).trim() !== "Enviar arquivo DIR") throw new Error("The pendência should send the DIR");
      await Promise.all([
        page.waitForURL(`**/pedidos/${pedidoUuid}/resumo`, { timeout: 30000 }),
        pendente.locator("form.pedido-parte-enviar input[type=file]").setInputFiles(direitoFile),
      ]);
      await expectCelula(await celula(0, names.lateral, "30"), "producao");
      if (!(await (await celula(0, names.lateral, "30")).innerText()).includes("DIR ESQ")) throw new Error("The cell should show both sides");

      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/impressao`);
      const lados = await page.locator(".impressao-arte").first().locator(`tr.impressao-linha[data-peca="${names.lateral}"]`)
        .evaluateAll((trs) => trs.map((tr) => `${tr.dataset.lado}=${tr.querySelector(".corte-total strong").textContent.trim()}`));
      if (lados.join("|") !== "direito=1 peça|esquerdo=1 peça") throw new Error(`Sides printed: ${lados.join("|")}`);
      await configurarParte(names.lateral, { pecasPorPar: 2, espelhada: false });
    });

    await test("An arte without molde shows no part picker", async () => {
      await uploadArte(loneFile, null, null);
      await openModalFor(loneFile);
      await page.waitForFunction(() => {
        const c = document.querySelector("[data-add-to-order-target='pecasContainer']");
        return c && c.hidden && c.children.length === 0;
      }, null, { timeout: 5000 });
      await page.locator(".add-to-order-footer .btn-secondary").click();
    });
  } finally {
    tempFiles.forEach((f) => { if (fs.existsSync(f)) fs.unlinkSync(f); });
  }
});
