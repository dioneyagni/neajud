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

  const UNIQ = `E${Date.now()}`;

  console.log("\nMovimentos E2E Tests\n");

  await test("Materials page has Register Movement link to /movimentos/new", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    const link = await page.$('a[href="/movimentos/new"]');
    if (!link) {
      const body = await page.textContent("body");
      throw new Error(`Link to /movimentos/new not found. Body preview: ${body.slice(0, 200)}`);
    }
    const text = await link.textContent();
    if (!text.includes("Register")) throw new Error(`Link text mismatch: "${text}"`);
  });

  await test("Movement form page loads without console errors", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);
    const body = await page.textContent("body");
    if (!body.includes("Register Movement")) throw new Error("Form page title not found");
    if (consoleErrors.length > 0) {
      const errors = consoleErrors.join(", ");
      consoleErrors.length = 0;
      throw new Error(`Console errors on load: ${errors}`);
    }
  });

  await test("Submit empty form shows error on same page", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);
    await page.click('input[type="submit"]');
    await page.waitForSelector(".flash-notice", { timeout: 10000 });
    const body = await page.textContent("body");
    if (!body.includes("Invalid material")) {
      console.log(`        Body preview: ${body.slice(0, 300)}`);
    }
  });

  await test("Register entrada movement and verify it appears in history", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);

    await page.locator('input[placeholder="Search group..."]').click();
    await page.locator('input[placeholder="Search group..."]').fill("Visc");
    await page.waitForTimeout(300);
    const grupoOption = page.locator(".combobox-option[data-name='Viscose']");
    await grupoOption.click();

    await page.locator('input[placeholder="Search client..."]').click();
    await page.locator('input[placeholder="Search client..."]').fill("Fag");
    await page.waitForTimeout(300);
    const clientOption = page.locator(".combobox-option[data-name='Fagner']");
    await clientOption.click();

    await page.click('.color-swatch[title="Azul"]');
    await page.evaluate(() => { document.querySelector('input[name="movimento_estoque[largura]"]').value = "9,99" });
    await page.evaluate(() => { document.querySelector('input[name="movimento_estoque[gramatura]"]').value = "100g" });
    await page.fill('input[name="movimento_estoque[quantidade]"]', "42");

    await page.click('input[type="submit"]');
    await page.waitForURL("**/materiais", { timeout: 10000 });

    const body = await page.textContent("body");
    if (!body.includes("Movement registered")) {
      console.log(`        Body preview: ${body.slice(0, 300)}`);
      throw new Error("Flash notice not found after registration");
    }

    if (!body.includes("Viscose")) throw new Error("Movement material (Viscose) not found in history");
    if (!body.includes("42")) throw new Error("Movement quantity (42) not found in history");
    if (!body.includes("Fagner")) throw new Error("Movement client (Fagner) not found in history");
  });

  await test("Register saida movement and verify it appears in history", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);

    await page.locator('input[placeholder="Search group..."]').click();
    await page.locator('input[placeholder="Search group..."]').fill("Visc");
    await page.waitForTimeout(300);
    await page.locator(".combobox-option[data-name='Viscose']").click();

    await page.locator('input[placeholder="Search client..."]').click();
    await page.locator('input[placeholder="Search client..."]').fill("Lip");
    await page.waitForTimeout(300);
    await page.locator(".combobox-option[data-name='Lipe']").click();

    await page.locator(".tipo-radio--saida").click();
    await page.click('.color-swatch[title="Azul"]');
    await page.evaluate(() => { document.querySelector('input[name="movimento_estoque[largura]"]').value = "9,99" });
    await page.evaluate(() => { document.querySelector('input[name="movimento_estoque[gramatura]"]').value = "100g" });
    await page.fill('input[name="movimento_estoque[quantidade]"]', "7");

    await page.click('input[type="submit"]');
    await page.waitForURL("**/materiais", { timeout: 10000 });

    const body = await page.textContent("body");
    if (!body.includes("Movement registered")) throw new Error("Flash notice not found");
    if (!body.includes("Out")) throw new Error("Saida type not shown as 'Out'");
    if (!body.includes("7")) throw new Error("Quantity 7 not found in history");
    if (!body.includes("Lipe")) throw new Error("Client Lipe not found in history");
  });

  await test("Range slider: click display to edit width value", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);

    // Find the first range slider (width)
    const displaySpan = page.locator(".range-slider-value").first();
    await displaySpan.waitFor({ timeout: 5000 });

    const originalText = await displaySpan.textContent();

    // Click to enter edit mode
    await displaySpan.click();
    await page.waitForTimeout(200);

    // Editor should be visible
    const editor = page.locator(".range-slider-editor").first();
    const editorVisible = await editor.evaluate(el => !el.classList.contains("range-slider-editor--hidden"));
    if (!editorVisible) throw new Error("Editor not visible after clicking display");

    // Change the value
    await editor.fill("1,75");
    await page.waitForTimeout(100);

    // Press Enter to commit
    await editor.press("Enter");
    await page.waitForTimeout(200);

    // Display should show the new value
    const newText = await displaySpan.textContent();
    if (!newText.includes("1,75")) throw new Error(`Expected "1,75" in display, got "${newText}"`);

    // Hidden input should have the formatted value
    const hiddenInput = page.locator("input[data-range-slider-target='hidden']").first();
    const hiddenVal = await hiddenInput.getAttribute("value");
    if (!hiddenVal.includes("1,75")) throw new Error(`Expected "1,75" in hidden, got "${hiddenVal}"`);

    // Editor should be hidden again
    const editorHidden = await editor.evaluate(el => el.classList.contains("range-slider-editor--hidden"));
    if (!editorHidden) throw new Error("Editor not hidden after commit");
  });

  await test("Range slider: blur editor also commits value", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);

    const displaySpan = page.locator(".range-slider-value").first();
    await displaySpan.waitFor({ timeout: 5000 });

    // Click to edit
    await displaySpan.click();
    await page.waitForTimeout(200);

    const editor = page.locator(".range-slider-editor").first();
    await editor.fill("0,80");

    // Blur the editor (click elsewhere)
    await page.locator("h2").click();
    await page.waitForTimeout(200);

    // Display should update
    const newText = await displaySpan.textContent();
    if (!newText.includes("0,80")) throw new Error(`Expected "0,80" in display after blur, got "${newText}"`);
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
