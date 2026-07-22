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

  const UNIQ = `M${Date.now()}`;

  console.log("\nModelos E2E Tests\n");

  await test("Modelos page loads", async () => {
    await page.goto(`${BASE_URL}/modelos`);
    const body = await page.textContent("body");
    if (!body.includes("Modelos")) throw new Error("Page heading not found");
  });

  await test("New Modelo button opens dialog", async () => {
    await page.goto(`${BASE_URL}/modelos`);
    await page.click('button:has-text("New Modelo")');
    await page.waitForTimeout(300);

    const dialog = page.locator("dialog.client-dialog");
    const isOpen = await dialog.evaluate((el) => el.open);
    if (!isOpen) throw new Error("Dialog did not open");
  });

  await test("Create a new modelo via dialog", async () => {
    await page.goto(`${BASE_URL}/modelos`);
    await page.click('button:has-text("New Modelo")');
    await page.waitForTimeout(300);

    await page.fill('input[name="modelo[nome]"]', `E2E Modelo ${UNIQ}`);

    // Select a client from the dropdown
    const clientSelect = page.locator('select[name="modelo[client_id]"]');
    const options = await clientSelect.locator("option").allTextContents();
    const clientOption = options.find((o) => o.includes("Fagner"));
    if (!clientOption) throw new Error("Fagner client not found in dropdown");
    await clientSelect.selectOption({ label: clientOption });

    await page.click('button[data-dialog-target="submitBtn"]:has-text("Register")');

    await page.waitForURL("**/modelos", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes(`E2E Modelo ${UNIQ}`)) {
      throw new Error(`New modelo not found in table. Body preview: ${body.slice(0, 300)}`);
    }
  });

  await test("Edit modelo via dialog", async () => {
    await page.goto(`${BASE_URL}/modelos`);

    const editBtn = page.locator('button:has-text("Edit")').first();
    await editBtn.click();
    await page.waitForTimeout(300);

    const title = await page.locator('[data-dialog-target="dialogTitle"]').textContent();
    if (!title.includes("Edit")) throw new Error(`Dialog title not 'Edit', got "${title}"`);

    await page.fill('input[name="modelo[nome]"]', `Edited Modelo ${UNIQ}`);
    await page.click('button[data-dialog-target="submitBtn"]:has-text("Update")');
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes(`Edited Modelo ${UNIQ}`)) {
      throw new Error("Edited modelo name not found");
    }
  });

  await test("Modelo show page displays details", async () => {
    await page.goto(`${BASE_URL}/modelos`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });

    const showLink = page.locator('a:has-text("Show")').first();
    const exists = await showLink.count();
    if (exists === 0) {
      console.log("        No modelo to show — skipping");
      return;
    }
    await showLink.click();
    await page.waitForLoadState("networkidle");

    const body = await page.textContent("body");
    if (!body.includes("Details")) {
      console.log(`        URL: ${page.url()}`);
      console.log(`        Body preview: ${body.slice(0, 300)}`);
      throw new Error("Details section not found");
    }
    const backLink = page.locator('a:has-text("All Modelos")');
    const backExists = await backLink.count();
    if (backExists === 0) throw new Error("All Modelos link not found");
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
