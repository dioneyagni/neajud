// Etapa 0.4 (docs/plano.md): nothing is deleted for good. Deleting moves a
// record to /lixeira; it keeps showing (with an "excluído em" badge) where it
// was already used, and Restore brings it back.
const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Lixeira E2E Tests", async ({ page, test }) => {
  const UNIQ = `L${Date.now()}`;
  const clientName = `Trash Client ${UNIQ}`;
  const arteName = `e2e-lixeira-${UNIQ}`;
  let arteUuid = null;
  let pedidoUuid = null;

  const csrf = () => page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");

  // Form POST from the page (Rails reads _method for PATCH/DELETE).
  async function postForm(url, fields) {
    const token = await csrf();
    return page.evaluate(async ({ url, fields, token }) => {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": token, Accept: "application/json, text/html" },
        body: new URLSearchParams(fields)
      });
      const type = response.headers.get("content-type") || "";
      return { ok: response.ok, json: type.includes("json") ? await response.json() : null };
    }, { url, fields, token });
  }

  async function restoreFromTrash(label) {
    await page.goto(`${BASE_URL}/lixeira`);
    const row = page.locator(".lixeira-item").filter({ hasText: label });
    if ((await row.count()) !== 1) throw new Error(`Expected one trash row for "${label}", got ${await row.count()}`);
    await row.locator('button:has-text("Restore")').click();
    await page.waitForURL("**/lixeira");
    const notice = await page.textContent(".flash-notice");
    if (!notice.includes("restored")) throw new Error(`Expected a "restored" notice, got "${notice}"`);
  }

  async function deleteClientFromIndex(name) {
    await page.goto(`${BASE_URL}/clients`);
    const row = page.locator(".clients-table tbody tr").filter({ hasText: name });
    await row.locator('button:has-text("Delete")').click();
    await page.waitForLoadState("networkidle");
  }

  await test("Lixeira link in the header opens the trash page", async () => {
    await page.goto(BASE_URL);
    await page.click('.header-nav a:has-text("Lixeira")');
    await page.waitForURL("**/lixeira");
    const heading = await page.textContent("h2");
    if (heading.trim() !== "Lixeira") throw new Error(`Expected heading "Lixeira", got "${heading}"`);
  });

  await test("Deleting a client moves it to the trash; Restore brings it back", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await postForm("/clients", { "client[name]": clientName, "client[responsible]": "Tester" });
    await deleteClientFromIndex(clientName);

    await page.goto(`${BASE_URL}/clients`);
    if ((await page.textContent("body")).includes(clientName)) throw new Error("Trashed client still listed in /clients");

    await page.goto(`${BASE_URL}/lixeira`);
    const row = page.locator('.lixeira-grupo[data-tipo="clients"] .lixeira-item').filter({ hasText: clientName });
    if ((await row.count()) !== 1) throw new Error("Trashed client not listed in /lixeira under Clients");
    const by = await row.locator("td").nth(2).textContent();
    if (!by.trim()) throw new Error("Trash row does not say who deleted it (IP)");

    await restoreFromTrash(clientName);
    await page.goto(`${BASE_URL}/clients`);
    if (!(await page.textContent(".clients-table")).includes(clientName)) throw new Error("Restored client not back in /clients");
  });

  await test("Registering a name that is in the trash offers restoring it instead", async () => {
    await deleteClientFromIndex(clientName);
    await page.goto(`${BASE_URL}/clients`);
    await page.click('button:has-text("New Client")');
    await page.fill('input[name="client[name]"]', clientName);
    await page.fill('input[name="client[responsible]"]', "Again");
    await page.click('button[data-dialog-target="submitBtn"]:has-text("Register")');
    await page.waitForSelector(".alert.flash-notice", { timeout: 10000 });
    const alert = await page.textContent(".alert.flash-notice");
    if (!alert.includes("is in the trash") || !alert.includes("Lixeira")) throw new Error(`Unexpected alert: "${alert}"`);
    if ((await page.textContent(".clients-table")).includes(clientName)) throw new Error("A duplicate client was created");
    await restoreFromTrash(clientName);
  });

  await test("Setup: an arte in a draft pedido", async () => {
    const artePath = path.join(__dirname, `${arteName}.tif`);
    try {
      execSync(`convert -size 50x50 xc:green 'TIFF:${artePath}'`);
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, artePath);
    } finally {
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
    }
    const href = await page.locator(`.stamp-card[data-filename="${arteName}"] a`).first().getAttribute("href");
    arteUuid = href.split("/").pop();
    const added = await postForm("/pedidos/adicionar_item", { arquivo_uuid: arteUuid, "grade[_total]": "2" });
    if (!added.json?.ok) throw new Error(`adicionar_item failed: ${JSON.stringify(added.json)}`);
    pedidoUuid = added.json.pedido_uuid;
  });

  await test("Deleting an arte hides it from the gallery; its page stays, with the badge", async () => {
    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    await page.click('button:has-text("Delete Arquivo")');
    await page.waitForURL(`${BASE_URL}/arquivos`);
    if ((await page.locator(`.stamp-card[data-filename="${arteName}"]`).count()) !== 0) throw new Error("Trashed arte still in the gallery");

    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    const badge = await page.textContent("h2 .badge-excluido");
    if (!badge.includes("excluído em")) throw new Error(`Unexpected badge "${badge}"`);
    if ((await page.locator('button:has-text("Delete Arquivo")').count()) !== 0) throw new Error("Delete button still shown on a trashed arte");
  });

  await test("A draft pedido using the trashed arte shows it with the badge and cannot be confirmed", async () => {
    await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
    if ((await page.locator(".badge-excluido").count()) === 0) throw new Error("No badge next to the trashed arte in the pedido");
    const pendencias = await page.textContent(".pedido-pendencias");
    if (!pendencias.includes(`${arteName} está na lixeira`)) throw new Error(`Blocker missing; pendências: "${pendencias}"`);
    if (!(await page.locator('button:has-text("Confirmar Pedido")').isDisabled())) throw new Error("Confirm is enabled with a trashed arte");
  });

  await test("Deleting the draft moves it to the trash; its page stays read-only", async () => {
    await page.click('button:has-text("Excluir Rascunho")');
    await page.waitForURL("**/pedidos");
    if ((await page.textContent("body")).includes(pedidoUuid.slice(0, 8))) throw new Error("Trashed pedido still listed in /pedidos");

    await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
    if ((await page.locator("h2 .badge-excluido").count()) !== 1) throw new Error("No badge on the trashed pedido");
    if ((await page.locator('button:has-text("Excluir Rascunho")').count()) !== 0) throw new Error("Trashed pedido is still editable");
  });

  await test("Restoring the arte and the pedido from the trash unblocks the draft", async () => {
    await restoreFromTrash(arteName);
    await restoreFromTrash(`Pedido ${pedidoUuid.slice(0, 8)}`);

    await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
    if ((await page.locator(".badge-excluido").count()) !== 0) throw new Error("Badge still shown after restoring");
    if ((await page.locator('button:has-text("Excluir Rascunho")').count()) !== 1) throw new Error("Restored draft is not editable again");
    await page.goto(BASE_URL);
    if ((await page.locator(`.stamp-card[data-filename="${arteName}"]`).count()) !== 1) throw new Error("Restored arte not back in the gallery");
  });
});
