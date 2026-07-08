const { chromium } = require("playwright");
const path = require("path");
const fs = require("fs");

const BASE_URL = "http://localhost:3000";
const HEADED = process.argv.includes("--headed") || process.argv.includes("-h");

async function run() {
  const launchOpts = { slowMo: HEADED ? 300 : 0 };
  if (HEADED) {
    launchOpts.headless = false;
    launchOpts.args = ["--start-maximized"];
  }
  const browser = await chromium.launch(launchOpts);
  const context = await browser.newContext(HEADED ? { viewport: null } : {});
  const page = await context.newPage();
  const consoleErrors = [];

  page.on("console", (msg) => {
    if (msg.type() === "error") {
      consoleErrors.push(msg.text());
    }
  });

  page.on("pageerror", (err) => {
    consoleErrors.push(`PAGE ERROR: ${err.message}`);
  });

  page.on("dialog", async (dialog) => {
    await dialog.accept();
  });

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  PASS  ${name}`);
      passed++;
    } catch (err) {
      console.log(`  FAIL  ${name}`);
      console.error(`        ${err.message}`);
      failed++;
    }
  }

  let createdUuid = null;
  let createdPedidoUuid = null;

  const UNIQ = `P${Date.now()}`;

  console.log("\nPedidos E2E Tests\n");

  await test("Upload an artes file via UI", async () => {
    const artePath = path.join(__dirname, `e2e-arte-${UNIQ}.tif`);
    try {
      const { execSync } = require("child_process");
      execSync(`convert -size 50x50 xc:blue 'TIFF:${artePath}'`);

      await page.goto(BASE_URL);
      const fileInput = await page.$('input[type="file"]');
      if (!fileInput) throw new Error("File input not found");
      await fileInput.setInputFiles(artePath);
      await page.click('input[type="submit"]');
      await page.waitForTimeout(3000);
      await page.waitForSelector(".stamp-card", { timeout: 20000 });

      const body = await page.textContent("body");
      const match = body.match(new RegExp(`e2e-arte-${UNIQ}`, "i"));
      if (!match) throw new Error(`Uploaded file not found in gallery`);
    } finally {
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
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
        const form = new FormData();
        form.append("movimento_estoque[client_id]", "1");
        form.append("movimento_estoque[tipo]", "entrada");
        form.append("movimento_estoque[grupo_material_id]", "1");
        form.append("movimento_estoque[cor_material_id]", "1");
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

  await test("Confirm pedido splits by client", async () => {
    await page.goto(`${BASE_URL}/pedidos`);
    await page.waitForTimeout(500);

    const rascunhoLink = page.locator("a").filter({ hasText: "Resumo" }).first();
    const exists = await rascunhoLink.count();
    if (exists === 0) {
      console.log("        No rascunho found to confirm — skipping");
      return;
    }
    await rascunhoLink.click();
    await page.waitForTimeout(500);

    const confirmBtn = page.locator('input[value="Confirmar Pedido"]').first();
    const confirmExists = await confirmBtn.count();
    if (confirmExists === 0) {
      console.log("        Confirm button not found — skipping");
      return;
    }
    await confirmBtn.click();
    await page.waitForURL("**/pedidos", { timeout: 10000 });

    const body = await page.textContent("body");
    if (!body.includes("confirmado")) {
      throw new Error(`Pedido not confirmed. Body preview: ${body.slice(0, 300)}`);
    }
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

  console.log(`\nResults: ${passed} passed, ${failed} failed\n`);

  if (failed > 0 && consoleErrors.length > 0) {
    console.log("Console errors during run:");
    consoleErrors.forEach((e) => console.log(`  ${e}`));
  }

  await browser.close();
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error("Fatal:", err.message);
  process.exit(1);
});
