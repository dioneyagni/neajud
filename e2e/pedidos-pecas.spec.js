const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { imageHasVisiblePixels } = require("./support/pixels");

// "Adicionar ao Pedido" lists every piece of the arte's modelo: checked
// pieces go to production, unchecked ones are excluded, and pieces without
// arte are pending (no checkbox).
runSpec("Pedidos E2E: pieces of the modelo (add-to-order modal + pedido page)", async ({ page, test }) => {
  const UNIQ = `PP${Date.now()}`;
  const names = { lateral: `Lateral ${UNIQ}`, lingua: `Lingua ${UNIQ}` };
  const tempFiles = [];

  // Solid-color TIF with an e2e- prefix, so bin/e2e cleans it if we abort.
  function makeArte(label, color) {
    const file = path.join(__dirname, `e2e-${label}-${UNIQ}.tif`);
    execSync(`convert -size 60x60 xc:${color} 'TIFF:${file}'`);
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

  // Peças + molde with both + client + modelo, through the app's own endpoints.
  async function setupModelo() {
    await page.goto(BASE_URL);
    for (const nome of Object.values(names)) await postForm("/pecas", [[ "peca[nome]", nome ]]);
    const pecaIds = {
      lateral: await findId(`/pecas/search?q=${encodeURIComponent(names.lateral)}`, "nome", names.lateral),
      lingua: await findId(`/pecas/search?q=${encodeURIComponent(names.lingua)}`, "nome", names.lingua),
    };
    const moldeNome = `Molde ${UNIQ}`;
    await postForm("/moldes", [[ "molde[nome]", moldeNome ], [ "molde[peca_ids][]", pecaIds.lateral ], [ "molde[peca_ids][]", pecaIds.lingua ]]);
    const moldeId = await findId(`/moldes/search?q=${encodeURIComponent(moldeNome)}`, "nome", moldeNome);
    const clientName = `Cliente ${UNIQ}`;
    await postForm("/clients", [[ "client[name]", clientName ], [ "client[responsible]", "E2E" ]]);
    const clientId = await findId(`/clients/search?q=${encodeURIComponent(clientName)}`, "name", clientName);
    const modeloNome = `Modelo ${UNIQ}`;
    await postForm("/modelos", [[ "modelo[nome]", modeloNome ], [ "modelo[client_id]", clientId ], [ "modelo[molde_id]", moldeId ]]);
    const modeloId = await findId(`/modelos/search?q=${encodeURIComponent(modeloNome)}`, "nome", modeloNome);
    if (!pecaIds.lateral || !pecaIds.lingua || !moldeId || !modeloId) {
      throw new Error(`Setup failed: ${JSON.stringify({ pecaIds, moldeId, clientId, modeloId })}`);
    }
    return { pecaIds, modeloId };
  }

  function cardFor(file) {
    return page.locator(".stamp-card").filter({ hasText: path.basename(file, ".tif") }).first();
  }

  // Uploads the arte and links it to the modelo + peça (update_modelo).
  async function uploadArte(file, modeloId, pecaId) {
    await page.goto(BASE_URL);
    await uploadFileAndWait(page, file);
    const href = await cardFor(file).locator("a").first().getAttribute("href");
    const uuid = href.split("/").pop();
    if (modeloId) {
      const status = await postForm(`/arquivos/${uuid}/update_modelo`, [[ "_method", "patch" ], [ "modelo_id", modeloId ], [ "peca_id", pecaId ]]);
      if (status >= 400) throw new Error(`update_modelo failed for ${uuid}: HTTP ${status}`);
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
    const nome = (await locator.innerText()).replace(/\s+/g, " ").trim();
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

  // Submits the open modal and returns the pedido uuid from adicionar_item.
  async function submitModal() {
    const responsePromise = page.waitForResponse((r) => r.url().endsWith("/pedidos/adicionar_item"));
    await page.locator("[data-add-to-order-target='submitBtn']").click();
    const json = await (await responsePromise).json();
    if (!json.ok) throw new Error(`adicionar_item failed: ${json.error}`);
    return json.pedido_uuid;
  }

  // Piece card on the pedido page, inside the itemIndex-th item (creation order).
  function pedidoPeca(itemIndex, nome) {
    return page.locator(".pedido-item").nth(itemIndex).locator(".pedido-peca").filter({ hasText: nome });
  }

  // Clicks a piece checkbox on the pedido page and waits for the save.
  async function togglePedidoPeca(card, checked) {
    const saved = page.waitForResponse((r) => r.url().includes("/alternar_peca"));
    await (checked ? card.locator(".pedido-peca-check").check() : card.locator(".pedido-peca-check").uncheck());
    const json = await (await saved).json();
    if (!json.ok) throw new Error(`alternar_peca failed: ${json.error}`);
  }

  async function expectPedidoPeca(card, estado, checked) {
    const cls = await card.getAttribute("class");
    if (!cls.includes(`pedido-peca--${estado}`)) throw new Error(`Expected ${estado}, got class "${cls}"`);
    if (checked !== undefined && (await card.locator(".pedido-peca-check").isChecked()) !== checked) {
      throw new Error(`Checkbox should be ${checked ? "checked" : "unchecked"} (${estado})`);
    }
  }

  function producaoRow(nome) {
    return page.locator("turbo-frame#pedido-producao tbody tr").filter({ hasText: nome });
  }

  let modelo;
  let pedidoUuid;
  const lateralFile = makeArte("lateral", "red");
  const linguaFile = makeArte("lingua", "blue");
  const loneFile = makeArte("lone", "green");
  let linguaUuid;

  try {
    await test("Setup: modelo with Lateral + Língua and a Lateral arte", async () => {
      modelo = await setupModelo();
      await uploadArte(lateralFile, modelo.modeloId, modelo.pecaIds.lateral);
    });

    await test("Modal lists both pieces; the one without arte is pending, without checkbox", async () => {
      await openModalFor(lateralFile);
      await pecaCard(names.lingua).waitFor({ timeout: 5000 });
      const count = await page.locator(".add-to-order-peca").count();
      if (count !== 2) throw new Error(`Expected 2 pieces, got ${count}`);
      if ((await pecaCard(names.lateral).locator(".add-to-order-peca-check").count()) !== 1) {
        throw new Error("Lateral should have a checkbox");
      }
      const pending = pecaCard(names.lingua);
      if (!(await pending.getAttribute("class")).includes("add-to-order-peca--pendente")) throw new Error("Língua should be pending");
      if ((await pending.locator(".add-to-order-peca-check").count()) !== 0) throw new Error("Pending piece must not have a checkbox");
      if (!(await pending.textContent()).includes("Pendente")) throw new Error("Pending badge missing");
    });

    await test("The piece preview loads with visible pixels", async () => {
      const src = await pecaCard(names.lateral).locator("img.add-to-order-peca-thumb").getAttribute("src");
      if (!src || !src.includes("/preview")) throw new Error(`Preview src missing: ${src}`);
      const res = await page.evaluate(async (u) => { const r = await fetch(u); return [ r.status, r.headers.get("content-type") ]; }, src);
      if (res[0] !== 200 || !String(res[1]).startsWith("image/")) throw new Error(`Preview response ${res}`);
      if (!(await imageHasVisiblePixels(page, src))) throw new Error("Piece preview has no visible pixels");
    });

    await test("Cancel closes the modal and clears the pieces", async () => {
      await page.locator(".add-to-order-footer .btn-secondary").click();
      if (await page.locator(".add-to-order-dialog[open]").count()) throw new Error("Modal still open after Cancel");
      if (await page.locator(".add-to-order-peca").count()) throw new Error("Pieces not cleared after Cancel");
    });

    await test("Adding while Língua has no arte stores it as pending on the pedido page", async () => {
      await openModalFor(lateralFile);
      await pecaCard(names.lingua).waitFor({ timeout: 5000 });
      pedidoUuid = await submitModal();
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      const lingua = pedidoPeca(0, names.lingua);
      await expectPedidoPeca(lingua, "pendente");
      if (await lingua.locator(".pedido-peca-check").count()) throw new Error("Pending piece must not have a checkbox");
      if (!(await lingua.innerText()).includes("sem arte")) throw new Error("Pending piece should say 'sem arte'");
      await expectPedidoPeca(pedidoPeca(0, names.lateral), "incluida", true);
    });

    await test("Unchecking a piece dims it and is sent as excluded on submit", async () => {
      linguaUuid = await uploadArte(linguaFile, modelo.modeloId, modelo.pecaIds.lingua);
      await openModalFor(lateralFile);
      const lingua = pecaCard(names.lingua);
      await lingua.locator(".add-to-order-peca-check").waitFor({ timeout: 5000 });
      await lingua.locator(".add-to-order-peca-check").uncheck();
      await waitForOpacity(pecaCard(names.lingua), "dimmed");

      const requestPromise = page.waitForRequest((r) => r.url().endsWith("/pedidos/adicionar_item") && r.method() === "POST");
      await page.locator("[data-add-to-order-target='submitBtn']").click();
      const body = (await requestPromise).postData() || "";
      if (!body.includes(linguaUuid)) throw new Error("Unchecked piece's arte uuid not sent as excluir_arquivos[]");
      await page.locator(".add-to-order-dialog[open]").waitFor({ state: "detached", timeout: 5000 }).catch(() => {});
      if (await page.locator(".add-to-order-dialog[open]").count()) throw new Error("Modal should close after adding");
    });

    await test("Pedido page shows the pieces as chosen in the modal, previews with visible pixels", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      await expectPedidoPeca(pedidoPeca(1, names.lateral), "incluida", true);
      await expectPedidoPeca(pedidoPeca(1, names.lingua), "excluida", false);
      await waitForOpacity(pedidoPeca(1, names.lingua), "dimmed");
      for (const nome of [ names.lateral, names.lingua ]) {
        const src = await pedidoPeca(1, nome).locator("img.pedido-peca-thumb").getAttribute("src");
        if (!(await imageHasVisiblePixels(page, src))) throw new Error(`${nome} preview has no visible pixels`);
      }
    });

    await test("Checking a piece on the pedido page saves it (survives reload)", async () => {
      await togglePedidoPeca(pedidoPeca(1, names.lingua), true);
      await waitForOpacity(pedidoPeca(1, names.lingua), "visible");
      await page.reload();
      await expectPedidoPeca(pedidoPeca(1, names.lingua), "incluida", true);
    });

    await test("Unchecking a piece on the pedido page saves it (survives reload)", async () => {
      await togglePedidoPeca(pedidoPeca(1, names.lateral), false);
      await waitForOpacity(pedidoPeca(1, names.lateral), "dimmed");
      await page.reload();
      await expectPedidoPeca(pedidoPeca(1, names.lateral), "excluida", false);
    });

    // State here: item 0 = Lateral checked + Língua pending; item 1 = Lateral
    // unchecked + Língua checked. Each item was added with quantity 1.
    await test("Produção lists only checked pieces, summed per peça", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      const rows = await page.locator("turbo-frame#pedido-producao tbody tr").evaluateAll((trs) => trs.map((tr) => tr.dataset.peca));
      if (JSON.stringify(rows) !== JSON.stringify([ names.lateral, names.lingua ])) throw new Error(`Rows ${JSON.stringify(rows)}`);
      const lateralTotal = (await producaoRow(names.lateral).locator("td strong").innerText()).trim();
      if (lateralTotal !== "1") throw new Error(`Lateral total should be 1 (only item 0 has it checked), got ${lateralTotal}`);
    });

    await test("Unchecking a piece removes it from Produção without reloading, re-checking brings it back", async () => {
      await togglePedidoPeca(pedidoPeca(1, names.lingua), false);
      await producaoRow(names.lingua).waitFor({ state: "detached", timeout: 5000 })
        .catch(() => { throw new Error("Língua row still in Produção after unchecking"); });
      await togglePedidoPeca(pedidoPeca(1, names.lingua), true);
      await producaoRow(names.lingua).waitFor({ timeout: 5000 })
        .catch(() => { throw new Error("Língua row did not come back after re-checking"); });
    });

    await test("A pending piece is listed and Confirmar is disabled on the pedido page", async () => {
      const box = page.locator(".pedido-pendencias");
      if (!(await box.innerText()).includes(names.lingua)) throw new Error("Pending Língua not listed");
      const confirmar = page.locator(`form[action$="/pedidos/${pedidoUuid}/confirmar"] button`);
      if (!(await confirmar.isDisabled())) throw new Error("Confirmar should be disabled while a piece is pending");
    });

    await test("The pedidos list shows a pending badge instead of Confirmar", async () => {
      await page.goto(`${BASE_URL}/pedidos`);
      const row = page.locator("tr").filter({ has: page.locator(`a[href="/pedidos/${pedidoUuid}"]`) });
      if (!(await row.locator(".pedido-pendentes-badge").innerText()).includes("1 pendente")) throw new Error("Pending badge missing");
      if (await row.locator(`a[href="/pedidos/${pedidoUuid}/confirmar"]`).count()) throw new Error("Confirmar link should be hidden");
    });

    await test("The server refuses to confirm while a piece is pending", async () => {
      const token = await csrf();
      await page.evaluate(async ({ uuid, token }) => {
        await fetch(`/pedidos/${uuid}/confirmar`, { method: "POST", headers: { "X-CSRF-Token": token } });
      }, { uuid: pedidoUuid, token });
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}`);
      const status = (await page.locator("h2 .badge").innerText()).trim();
      if (status !== "rascunho") throw new Error(`Pedido should stay rascunho, got ${status}`);
    });

    await test("Re-checking a piece restores it", async () => {
      await openModalFor(lateralFile);
      const check = pecaCard(names.lingua).locator(".add-to-order-peca-check");
      await check.waitFor({ timeout: 5000 });
      await check.uncheck();
      await check.check();
      await waitForOpacity(pecaCard(names.lingua), "visible");
      await page.locator(".add-to-order-footer .btn-secondary").click();
    });

    await test("An arte without modelo shows no piece picker", async () => {
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
