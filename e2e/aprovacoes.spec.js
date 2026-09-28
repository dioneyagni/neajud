// Etapa 0.5 (4/4): an arte shows nothing until someone sends it for approval
// (changed before merge, 28/09/2026); then its approval is registered from a
// pedido (returning there) or the arte page, with an optional attachment;
// cancelling keeps the history.
const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Aprovações E2E Tests", async ({ page, test }) => {
  const UNIQ = `A${Date.now()}`;
  const arteName = `e2e-aprovacao-${UNIQ}`;
  const anexoPath = path.join(__dirname, `e2e-anexo-${UNIQ}.png`);
  let arteUuid = null;
  let pedidoUuid = null;

  async function postForm(url, fields) {
    const token = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");
    return page.evaluate(async ({ url, fields, token }) => {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": token, Accept: "application/json" },
        body: new URLSearchParams(fields)
      });
      return response.json();
    }, { url, fields, token });
  }

  await test("Setup: an arte in a draft pedido", async () => {
    const artePath = path.join(__dirname, `${arteName}.tif`);
    try {
      execSync(`convert -size 40x40 xc:orange 'TIFF:${artePath}'`);
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, artePath);
    } finally {
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
    }
    arteUuid = (await page.locator(`.stamp-card[data-filename="${arteName}"] a`).first().getAttribute("href")).split("/").pop();
    const added = await postForm("/pedidos/adicionar_item", { arquivo_uuid: arteUuid, "grade[_total]": "1" });
    if (!added.ok) throw new Error(`adicionar_item failed: ${JSON.stringify(added)}`);
    pedidoUuid = added.pedido_uuid;
  });

  // Not sent yet: no "waiting" badge and no register button in the pedido.
  await test("Before it is sent, the pedido shows no approval badge or button", async () => {
    await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
    await page.locator(".pedido-peca").first().waitFor();
    if ((await page.locator(".badge-aprovacao").count()) !== 0) throw new Error("Approval badge shown before sending");
    if ((await page.locator("a.pedido-peca-aprovar").count()) !== 0) throw new Error("Register button shown before sending");
  });

  await test("Send for approval on the arte page; the pedido then shows it waiting", async () => {
    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    await waitForText(page, "Not sent for approval.");
    await page.click('#aprovacao-section button:has-text("Send for approval")');
    await waitForText(page, "sent for approval.");
    await page.locator('#aprovacao-section[data-estado="aguardando"]').waitFor();
    await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
    await waitForText(page, "Aguardando aprovação");
  });

  await test("Registering from the pedido (with an attachment) returns to the pedido, approved", async () => {
    execSync(`convert -size 20x20 xc:green 'PNG:${anexoPath}'`);
    try {
      await page.click('a.pedido-peca-aprovar:has-text("Registrar aprovação")');
      await page.waitForURL(/\/aprovacoes\/new/);
      await page.check('input[name="aprovacao[canal]"][value="whatsapp"]');
      await page.fill('textarea[name="aprovacao[observacao]"]', "Cliente aprovou no grupo");
      await page.setInputFiles('input[name="aprovacao[anexo]"]', anexoPath);
      await page.click('input[type="submit"][value="Register approval"]');
      await page.waitForURL(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
      await waitForText(page, "Aprovada — v1, WhatsApp");
    } finally {
      if (fs.existsSync(anexoPath)) fs.unlinkSync(anexoPath);
    }
  });

  await test("The arte page lists the approval with its attachment as a download", async () => {
    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    const linha = page.locator(".aprovacao-historico tbody tr").first();
    const texto = await linha.textContent();
    if (!texto.includes("WhatsApp") || !texto.includes("Cliente aprovou no grupo")) throw new Error(`History row: ${texto.replace(/\s+/g, " ")}`);
    const href = await linha.locator("a").first().getAttribute("href");
    const response = await page.request.get(new URL(href, BASE_URL).href);
    if (!response.ok() || !response.headers()["content-disposition"].includes("attachment")) throw new Error("Attachment is not downloaded as a file");
  });

  await test("Cancelling the approval keeps it in the history; registering again works without an attachment", async () => {
    await page.click('#aprovacao-section button:has-text("Cancel")');
    await waitForText(page, "Approval cancelled");
    await waitForText(page, "Aguardando aprovação");
    await page.click('#aprovacao-section a:has-text("Register approval")');
    await page.check('input[name="aprovacao[canal]"][value="presencial"]');
    await page.click('input[type="submit"][value="Register approval"]');
    await waitForText(page, "Aprovada — v1, Presencial");
    if ((await page.locator(".aprovacao-historico tr.aprovacao--cancelada").count()) !== 1) throw new Error("Cancelled approval not kept in the history");
  });

  await test("The version in use is labelled Em uso", async () => {
    if ((await page.locator('.stamp-card-badge:has-text("Em uso")').count()) !== 1) throw new Error("No Em uso badge on the version in use");
  });
});
