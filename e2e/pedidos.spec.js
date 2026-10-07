const path = require("path");
const fs = require("fs");
const { uploadFileAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Pedidos E2E Tests", async ({ page, test }) => {
  let createdUuid = null;
  let createdPedidoUuid = null;

  const UNIQ = `P${Date.now()}`;


  await test("Upload an artes file via UI", async () => {
    const artePath = path.join(__dirname, `e2e-arte-${UNIQ}.tif`);
    try {
      const { execSync } = require("child_process");
      execSync(`convert -size 50x50 xc:blue 'TIFF:${artePath}'`);

      await page.goto(BASE_URL);
      await uploadFileAndWait(page, artePath);

      const body = await page.textContent("body");
      const match = body.match(new RegExp(`e2e-arte-${UNIQ}`, "i"));
      if (!match) throw new Error(`Uploaded file not found in gallery`);
    } finally {
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
    }
  });

  // Confirming requires every checked piece to have a corte (see
  // PedidoBloqueiosService): organize a copy of 29-30.dxf and pick its
  // tamanho for the arte, the same way the arte page's Size Selection does.
  await test("Setup: give the arte a corte (organized DXF tamanho)", async () => {
    const dxfPath = path.join(__dirname, `e2e-corte-${UNIQ}.dxf`);
    fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "29-30.dxf"), dxfPath);
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, dxfPath);
      const uuidOf = async (name) => (await page.locator(".stamp-card").filter({ hasText: name }).first()
        .locator("a").first().getAttribute("href")).split("/").pop();
      const corteUuid = await uuidOf(`e2e-corte-${UNIQ}`);
      const arteUuid = await uuidOf(`e2e-arte-${UNIQ}`);
      const token = await getCsrfToken(page);
      const ok = await page.evaluate(async ({ token, corteUuid, arteUuid, uniq }) => {
        const form = (fields) => new URLSearchParams({ authenticity_token: token, ...fields });
        const post = (url, fields) => fetch(url, { method: "POST", body: form(fields), headers: { "Content-Type": "application/x-www-form-urlencoded" } });
        await post("/pecas", { "peca[nome]": `Peca ${uniq}` });
        const peca = (await (await fetch(`/pecas/search?q=${encodeURIComponent(`Peca ${uniq}`)}`)).json())[0];
        // Etapa 1.1 (3/5): an official modelo (the peça is unique per run).
        const modelo = (await (await fetch("/modelos/search?q=Tenis")).json()).find((m) => m.nome === "Tenis");
        const organized = await post(`/arquivos/${corteUuid}/organize`, {
          _method: "patch", modelo_uuid: modelo.id, peca_uuid: peca.id,
          "tamanhos[0][nome]": "34", "tamanhos[0][width_mm]": "150", "tamanhos[0][height_mm]": "250", "tamanhos[0][area_mm2]": "8000"
        });
        // This arte has no molde: read the size's uuid from the corte's own page.
        const html = await (await fetch(`/arquivos/${corteUuid}`)).text();
        const tamanhoUuid = html.match(/data-tamanho-uuid="([^"]+)"/)?.[1];
        if (!organized.ok || !tamanhoUuid) return false;
        return (await post(`/arquivos/${arteUuid}/update_tamanho`, { _method: "patch", tamanho_uuid: tamanhoUuid })).ok;
      }, { token, corteUuid, arteUuid, uniq: UNIQ });
      if (!ok) throw new Error("Could not organize the DXF and link its tamanho to the arte");
    } finally {
      if (fs.existsSync(dxfPath)) fs.unlinkSync(dxfPath);
    }
  });

  await test("Homepage shows Pedidos link in header", async () => {
    await page.goto(BASE_URL);
    const body = await page.textContent("body");
    if (!body.includes("Pedidos")) throw new Error("Pedidos link not found in header");
  });

  await test("Card has 'Adicionar ao Pedido' button for artes files", async () => {
    await page.goto(BASE_URL);
    const btn = page.locator(".btn-add-to-order").first();
    await btn.waitFor({ timeout: 10000 });
    const visible = await btn.isVisible();
    if (!visible) throw new Error("Add to order button not visible");
  });

  async function clickAddToOrder(page) {
    const btn = page.locator(".btn-add-to-order").first();
    await btn.waitFor({ timeout: 10000 });
    await btn.click({ force: true });
    await page.waitForTimeout(500);
  }

  await test("Clicking 'Adicionar ao Pedido' opens the modal", async () => {
    await page.goto(BASE_URL);
    await clickAddToOrder(page);

    const dialog = page.locator(".add-to-order-dialog");
    const isOpen = await dialog.evaluate(el => el.open);
    if (!isOpen) throw new Error("Modal did not open");
  });

  await test("Modal displays arte info (filename)", async () => {
    await page.goto(BASE_URL);
    await clickAddToOrder(page);

    const filename = page.locator("[data-add-to-order-target='filename']");
    const text = await filename.textContent();
    if (!text) throw new Error("Filename not shown in modal");
  });

  await test("Modal can be closed via Cancel button", async () => {
    await page.goto(BASE_URL);
    await clickAddToOrder(page);

    const cancelBtn = page.locator(".add-to-order-footer .btn-secondary").first();
    await cancelBtn.waitFor({ timeout: 5000 });
    await cancelBtn.click();
    await page.waitForTimeout(300);

    const dialog = page.locator(".add-to-order-dialog");
    const isOpen = await dialog.evaluate(el => el.open);
    if (isOpen) throw new Error("Modal did not close after Cancel");
  });

  async function getCsrfToken(page) {
    return page.evaluate(() => {
      const meta = document.querySelector("meta[name='csrf-token']");
      return meta ? meta.content : "";
    });
  }

  // GrupoMaterial/CorMaterial have no seed data (see AGENTS.md) — find_or_create
  // each via the app's own "Register new" endpoints instead of assuming a
  // fixed id, then create the movimento with the ids that actually exist.
  async function ensureMaterialExists(page) {
    const res = await page.evaluate(async () => {
      const r = await fetch("/materiais/search?q=Oxford", {
        headers: { "Accept": "application/json" }
      });
      return await r.json();
    });

    if (res.length === 0) {
      await page.goto(`${BASE_URL}/materiais/new`);
      await page.waitForTimeout(500);
      const token = await getCsrfToken(page);

      await page.evaluate(async (csrf) => {
        async function findOrCreate(kind, nome) {
          const searchUrl = kind === "grupo" ? `/materiais/grupos?q=${encodeURIComponent(nome)}` : "/materiais/cores";
          const found = await (await fetch(searchUrl, { headers: { Accept: "application/json" } })).json();
          const existing = found.find((r) => r.nome === nome);
          if (existing) return existing.id;

          const form = new FormData();
          form.append(`${kind === "grupo" ? "grupo_material" : "cor_material"}[nome]`, nome);
          await fetch(`/materiais/create_${kind}`, { method: "POST", headers: { "X-CSRF-Token": csrf }, body: form, redirect: "manual" });
          const created = await (await fetch(searchUrl, { headers: { Accept: "application/json" } })).json();
          return created.find((r) => r.nome === nome)?.id;
        }

        const grupoId = await findOrCreate("grupo", "Oxford");
        const corId = await findOrCreate("cor", "Branco");

        const clientName = "E2E Pedidos Material Setup";
        await fetch("/clients", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
          body: new URLSearchParams({ "client[name]": clientName, "client[responsible]": "Tester" })
        });
        const clients = await (await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`)).json();
        const clientId = clients.find((c) => c.name === clientName)?.id;

        const form = new FormData();
        form.append("movimento_estoque[client_uuid]", clientId);
        form.append("movimento_estoque[tipo]", "entrada");
        form.append("movimento_estoque[grupo_material_uuid]", grupoId);
        form.append("movimento_estoque[cor_material_uuid]", corId);
        form.append("movimento_estoque[largura]", "1.40");
        form.append("movimento_estoque[gramatura]", "100g");
        form.append("movimento_estoque[quantidade]", "50");
        form.append("movimento_estoque[valor]", "");
        await fetch("/materiais", {
          method: "POST",
          headers: { "X-CSRF-Token": csrf },
          body: form,
          redirect: "manual"
        });
      }, token);
    }
  }

  // Regression: pedido d7b86d8a got an item with total 0 and was confirmed.
  await test("Adding with quantity 0 is refused in the modal", async () => {
    await page.goto(BASE_URL);
    await clickAddToOrder(page);
    const inputs = page.locator(".add-to-order-qtd-total, .add-to-order-grade-input");
    await inputs.first().waitFor({ timeout: 5000 });
    for (const input of await inputs.all()) await input.fill("0");
    await page.locator("[data-add-to-order-target='submitBtn']").click();
    const error = page.locator("[data-add-to-order-target='errorContainer']:not(.add-to-order-error--hidden)");
    await error.waitFor({ timeout: 5000 });
    if (!(await error.innerText()).includes("quantidade total 0")) throw new Error(`Unexpected error: ${await error.innerText()}`);
    if (!(await page.locator(".add-to-order-dialog").evaluate((el) => el.open))) throw new Error("Modal should stay open");
    await page.locator(".add-to-order-footer .btn-secondary").click();
  });

  await test("Add item to pedido and verify it appears in resumo", async () => {
    await page.goto(BASE_URL);
    await ensureMaterialExists(page);

    await page.goto(BASE_URL);
    await page.waitForTimeout(500);

    await clickAddToOrder(page);

    // Search for material
    const materialInput = page.locator(".add-to-order-material .combobox-input");
    await materialInput.waitFor({ timeout: 5000 });
    await materialInput.click();
    await materialInput.fill("Oxford");
    await page.waitForTimeout(500);

    // Select the first material option
    const materialOption = page.locator(".combobox-option").first();
    await materialOption.waitFor({ timeout: 5000 });
    await materialOption.click();
    await page.waitForTimeout(200);

    // Set quantity in the grade/total field
    const qtdInput = page.locator(".add-to-order-qtd-total, .add-to-order-grade-input").first();
    await qtdInput.waitFor({ timeout: 5000 });
    await qtdInput.fill("3");

    // Submit
    const submitBtn = page.locator("[data-add-to-order-target='submitBtn']");
    await submitBtn.click();
    await page.waitForTimeout(500);

    // Modal should close
    const dialog = page.locator(".add-to-order-dialog");
    const isOpen = await dialog.evaluate(el => el.open);
    if (isOpen) throw new Error("Modal did not close after submit");

    // Navigate to the draft resumo page
    await page.goto(`${BASE_URL}/pedidos`);
    await page.waitForSelector(".clients-table", { timeout: 10000 });

    const pedidosBody = await page.textContent("body");
    if (!pedidosBody.includes("rascunho")) throw new Error("Draft pedido not found on pedidos page");
  });

  // The factory floor downloads each size's DXF from the pedido's Corte page
  // (Etapa 1.2, 3/3 parte 3b), reached from the pedido's side panel.
  async function abrirCorte() {
    await Promise.all([ page.waitForURL(/\/pedidos\/[0-9a-f-]{36}\/corte$/), page.locator("a.pedido-ir-corte").click() ]);
  }

  async function downloadProducaoDxf() {
    const link = page.locator("tr.corte-linha a.corte-dxf").first();
    await link.waitFor({ timeout: 5000 });
    const [download] = await Promise.all([ page.waitForEvent("download", { timeout: 15000 }), link.click() ]);
    const filename = download.suggestedFilename();
    if (filename !== `e2e-corte-${UNIQ} - 34.dxf`) throw new Error(`Unexpected DXF name: ${filename}`);
    const content = fs.readFileSync(await download.path(), "utf8");
    if (!content.includes("SECTION") || !content.includes("ENTITIES")) throw new Error(`Not a DXF: ${content.slice(0, 80)}`);
  }

  let pedidoConfirmadoPath = null;

  await test("Corte: the size's line downloads its DXF; the zip has every size", async () => {
    await page.goto(`${BASE_URL}/pedidos`);
    await page.locator("a").filter({ hasText: "Resumo" }).first().click();
    await page.locator("a.pedido-ir-corte").waitFor({ timeout: 5000 });
    pedidoConfirmadoPath = new URL(page.url()).pathname.replace(/\/resumo$/, "");
    await abrirCorte();
    // The size's drawing loads (PNG made with its DXF).
    const previa = page.locator("tr.corte-linha img.corte-previa").first();
    if (!(await previa.evaluate((img) => img.complete && img.naturalWidth > 0))) await previa.evaluate((img) => new Promise((ok, erro) => { img.onload = ok; img.onerror = () => erro(new Error(`Preview failed: ${img.src}`)); }));
    await downloadProducaoDxf();
    const [zip] = await Promise.all([ page.waitForEvent("download", { timeout: 30000 }), page.locator("a.corte-zip").click() ]);
    if (!/^Corte [0-9a-f]{8}\.zip$/.test(zip.suggestedFilename())) throw new Error(`Unexpected zip name: ${zip.suggestedFilename()}`);
    const bytes = fs.readFileSync(await zip.path());
    if (bytes.subarray(0, 2).toString() !== "PK" || !bytes.includes(Buffer.from(` - e2e-corte-${UNIQ}.dxf`))) throw new Error("The zip should hold the size's DXF, named by part, size and corte");
  });

  // Used to look for input[value="Confirmar Pedido"] — button_to renders a
  // <button> — and "skip" when missing, so it passed without ever confirming.
  // Regression (01/10/2026, ed6a2aba): this arte was added without client, so
  // the draft has none; confirming would have made a pedido without client.
  await test("A draft whose arte has no client says so, blocks Confirmar, and adopts the client once the arte gets one", async () => {
    await page.goto(`${BASE_URL}/pedidos`);
    await page.locator("a").filter({ hasText: "Resumo" }).first().click();
    await page.locator(".pedido-cliente-previsto").filter({ hasText: "ainda sem cliente" }).waitFor({ timeout: 5000 });
    await page.locator(".pedido-pendencia--arte_sem_cliente").filter({ hasText: `e2e-arte-${UNIQ} sem cliente` }).waitFor();
    if (!(await page.locator('form[action$="/confirmar"] button').isDisabled())) throw new Error("Confirmar should be blocked by the arte without client");

    const resumoUrl = page.url();
    const arte = (await page.locator(".pedido-pendencia--arte_sem_cliente a").first().getAttribute("href")).split("/").pop();
    const ok = await page.evaluate(async ({ uniq, arte }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const post = (url, campos) => fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) });
      await post("/clients", { "client[name]": `Pedido Client ${uniq}`, "client[responsible]": "T" });
      const client = (await (await fetch(`/clients/search?q=${encodeURIComponent(`Pedido Client ${uniq}`)}`)).json())[0];
      return (await post(`/arquivos/${arte}/update_client`, { _method: "patch", client_uuid: client.id })).ok;
    }, { uniq: UNIQ, arte });
    if (!ok) throw new Error("Could not give the arte a client");
    await page.goto(resumoUrl);
    await page.getByText(`Cliente: Pedido Client ${UNIQ}`).waitFor({ timeout: 5000 });
  });

  await test("Confirm pedido: a valid draft (quantity > 0, piece with corte) is confirmed", async () => {
    await page.goto(`${BASE_URL}/pedidos`);
    const resumo = page.locator("a").filter({ hasText: "Resumo" }).first();
    await resumo.waitFor({ timeout: 5000 });
    await resumo.click();
    const confirmBtn = page.locator('form[action$="/confirmar"] button');
    await confirmBtn.waitFor({ timeout: 5000 });
    if (await confirmBtn.isDisabled()) {
      const pendencias = await page.locator(".pedido-pendencias").innerText().catch(() => "");
      throw new Error(`Confirmar is disabled; pendências: ${pendencias}`);
    }
    await Promise.all([ page.waitForURL("**/pedidos", { timeout: 10000 }), confirmBtn.click() ]);
    const body = await page.textContent("body");
    if (!body.includes("Pedido confirmed")) throw new Error(`Pedido not confirmed. Body preview: ${body.slice(0, 300)}`);
  });

  await test("Corte downloads still work on the confirmed pedido (factory floor)", async () => {
    if (!pedidoConfirmadoPath) throw new Error("Pedido path not captured");
    await page.goto(`${BASE_URL}${pedidoConfirmadoPath}`);
    const status = (await page.locator("h2 .badge").innerText()).trim();
    if (status !== "confirmado") throw new Error(`Expected confirmado, got ${status}`);
    await abrirCorte();
    await downloadProducaoDxf();
  });

  await test("Create new draft pedido from pedidos page", async () => {
    await page.goto(`${BASE_URL}/pedidos`, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(1000);

    const newBtn = page.locator("input.btn-primary, .btn-primary, .button_to input[type='submit']").first();
    await newBtn.waitFor({ timeout: 5000 });
    await newBtn.click();
    await page.waitForURL("**/pedidos/**/resumo", { timeout: 10000 });

    const body = await page.textContent("body");
    if (!body.includes("rascunho")) throw new Error("New draft pedido page did not show rascunho status");
  });
});
