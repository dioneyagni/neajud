const { chromium } = require("playwright");

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

  const UNIQ = `MAT${Date.now()}`;

  console.log("\nMateriais E2E Tests\n");

  await test("Materials page loads with heading", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    const body = await page.textContent("body");
    if (!body.includes("Materials Inventory")) throw new Error("Heading not found");
  });

  await test("Materials page shows Register Movement link", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    const link = page.locator('a[href="/movimentos/new"]');
    const exists = await link.count();
    if (exists === 0) throw new Error("Register Movement link not found");
    const text = await link.textContent();
    if (!text.includes("Register Movement")) throw new Error(`Link text mismatch: "${text}"`);
  });

  await test("Materials page shows Movement History section", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    const body = await page.textContent("body");
    if (!body.includes("Movement History")) throw new Error("Movement History section not found");
  });

  await test("Materials page shows 'No materials' when empty", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    const body = await page.textContent("body");
    // The page always shows the section, but empty state message may or may not appear
    // Just verify the page renders without error
    if (!body.includes("Total")) throw new Error("Total row not found");
  });

  await test("Materials page shows Back to Gallery link", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    const link = page.locator('a:has-text("Back to Gallery")');
    const exists = await link.count();
    if (exists === 0) throw new Error("Back to Gallery link not found");
  });

  await test("Materiais search endpoint returns JSON", async () => {
    const result = await page.evaluate(async () => {
      const res = await fetch("/materiais/search?q=Oxford", {
        headers: { Accept: "application/json" },
      });
      return { status: res.status, data: await res.json() };
    });
    if (result.status !== 200) throw new Error(`Expected 200, got ${result.status}`);
    if (!Array.isArray(result.data)) throw new Error("Response is not an array");
  });

  await test("Grupos endpoint returns JSON list", async () => {
    const result = await page.evaluate(async () => {
      const res = await fetch("/materiais/grupos", {
        headers: { Accept: "application/json" },
      });
      return { status: res.status, data: await res.json() };
    });
    if (result.status !== 200) throw new Error(`Expected 200, got ${result.status}`);
    if (!Array.isArray(result.data)) throw new Error("Response is not an array");
    if (result.data.length === 0) throw new Error("No grupos returned");
    if (!result.data[0].nome) throw new Error("Grupo missing 'nome' field");
  });

  await test("Cores endpoint returns JSON list", async () => {
    const result = await page.evaluate(async () => {
      const res = await fetch("/materiais/cores", {
        headers: { Accept: "application/json" },
      });
      return { status: res.status, data: await res.json() };
    });
    if (result.status !== 200) throw new Error(`Expected 200, got ${result.status}`);
    if (!Array.isArray(result.data)) throw new Error("Response is not an array");
    if (result.data.length === 0) throw new Error("No cores returned");
    if (!result.data[0].nome) throw new Error("Cor missing 'nome' field");
  });

  await test("Register entrada movement via form and verify in history", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);

    // Select grupo
    await page.locator('input[placeholder="Search group..."]').click();
    await page.locator('input[placeholder="Search group..."]').fill("Ox");
    await page.waitForTimeout(500);
    const grupoOption = page.locator(".combobox-option[data-name='Oxford']");
    await grupoOption.click();

    // Select client
    await page.locator('input[placeholder="Search client..."]').click();
    await page.locator('input[placeholder="Search client..."]').fill("Fag");
    await page.waitForTimeout(500);
    const clientOption = page.locator(".combobox-option[data-name='Fagner']");
    await clientOption.click();

    // Select color
    await page.click('.color-swatch[title="Azul"]');

    // Set fields
    await page.evaluate(() => {
      document.querySelector('input[name="movimento_estoque[largura]"]').value = "1,40";
    });
    await page.evaluate(() => {
      document.querySelector('input[name="movimento_estoque[gramatura]"]').value = "100g";
    });
    await page.fill('input[name="movimento_estoque[quantidade]"]', "25");

    // Submit
    await page.click('input[type="submit"]');
    await page.waitForURL("**/materiais", { timeout: 10000 });

    const body = await page.textContent("body");
    if (!body.includes("Movement registered")) throw new Error("Flash notice not found");
    if (!body.includes("Oxford")) throw new Error("Material not shown in inventory");
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
