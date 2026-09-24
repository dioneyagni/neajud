const path = require("path");
const fs = require("fs");
const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Movimentos E2E Tests", async ({ page, test, consoleErrors }) => {
  const UNIQ = `E${Date.now()}`;

  // GrupoMaterial/CorMaterial/Client have no seed data (see AGENTS.md) —
  // each test below provisions whatever it needs through the app's own
  // "Register new" endpoints, rather than assuming shared cross-file state.
  async function csrfToken() {
    return page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");
  }

  async function ensureGrupo(nome) {
    const csrf = await csrfToken();
    return page.evaluate(async ({ csrf, nome }) => {
      const found = await (await fetch(`/materiais/grupos?q=${encodeURIComponent(nome)}`)).json();
      if (found.find((g) => g.nome === nome)) return;
      await fetch("/materiais/create_grupo", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "grupo_material[nome]": nome })
      });
    }, { csrf, nome });
  }

  async function ensureCor(nome) {
    const csrf = await csrfToken();
    return page.evaluate(async ({ csrf, nome }) => {
      const found = await (await fetch("/materiais/cores")).json();
      if (found.find((c) => c.nome === nome)) return;
      await fetch("/materiais/create_cor", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "cor_material[nome]": nome })
      });
    }, { csrf, nome });
  }

  async function ensureClient(nome) {
    const csrf = await csrfToken();
    return page.evaluate(async ({ csrf, nome }) => {
      const found = await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json();
      if (found.find((c) => c.name === nome)) return;
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "client[name]": nome, "client[responsible]": "Tester" })
      });
    }, { csrf, nome });
  }


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
    const entradaClientName = `Entrada Client ${UNIQ}`;
    await page.goto(`${BASE_URL}/materiais`);
    await ensureGrupo("Viscose");
    await ensureCor("Azul");
    await ensureClient(entradaClientName);

    await page.goto(`${BASE_URL}/movimentos/new`);

    await page.locator('input[placeholder="Search group..."]').click();
    await page.locator('input[placeholder="Search group..."]').fill("Visc");
    await page.waitForTimeout(300);
    const grupoOption = page.locator(".combobox-option[data-name='Viscose']");
    await grupoOption.click();

    await page.locator('input[placeholder="Search client..."]').click();
    await page.locator('input[placeholder="Search client..."]').fill(entradaClientName.slice(0, 6));
    await page.waitForTimeout(300);
    const clientOption = page.locator(`.combobox-option[data-name='${entradaClientName}']`);
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
    if (!body.includes(entradaClientName)) throw new Error(`Movement client (${entradaClientName}) not found in history`);
  });

  await test("Register saida movement and verify it appears in history", async () => {
    const saidaClientName = `Saida Client ${UNIQ}`;
    await page.goto(`${BASE_URL}/materiais`);
    await ensureGrupo("Viscose");
    await ensureCor("Azul");
    await ensureClient(saidaClientName);

    await page.goto(`${BASE_URL}/movimentos/new`);

    await page.locator('input[placeholder="Search group..."]').click();
    await page.locator('input[placeholder="Search group..."]').fill("Visc");
    await page.waitForTimeout(300);
    await page.locator(".combobox-option[data-name='Viscose']").click();

    await page.locator('input[placeholder="Search client..."]').click();
    await page.locator('input[placeholder="Search client..."]').fill(saidaClientName.slice(0, 6));
    await page.waitForTimeout(300);
    await page.locator(`.combobox-option[data-name='${saidaClientName}']`).click();

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
    if (!body.includes(saidaClientName)) throw new Error(`Client ${saidaClientName} not found in history`);
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

  // ── Register New Color dialog (CorMaterial has no seed data — see AGENTS.md) ──

  await test("Register New Color dialog: Cancel closes without creating a color", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);

    const newSwatch = page.locator(".color-swatch--new");
    await newSwatch.waitFor({ timeout: 5000 });
    await newSwatch.click();

    const dialog = page.locator('dialog[data-color-picker-target="dialog"]');
    const isOpen = await dialog.evaluate((el) => el.open);
    if (!isOpen) throw new Error("Dialog did not open");

    // Centered in viewport
    const box = await dialog.evaluate((el) => {
      const r = el.getBoundingClientRect();
      return { left: r.left, right: window.innerWidth - r.right, top: r.top, bottom: window.innerHeight - r.bottom };
    });
    if (Math.abs(box.left - box.right) > 5) throw new Error(`Dialog not horizontally centered: ${JSON.stringify(box)}`);

    await page.click('button[data-action="click->color-picker#closeNew"]');
    await page.waitForTimeout(200);
    const stillOpen = await dialog.evaluate((el) => el.open);
    if (stillOpen) throw new Error("Dialog did not close after Cancel");
  });

  await test("Register New Color dialog: register a new color and select it", async () => {
    const colorName = "Roxo";
    await page.goto(`${BASE_URL}/movimentos/new`);

    const before = await page.locator(`.color-swatch[title="${colorName}"]`).count();
    if (before > 0) throw new Error(`"${colorName}" swatch already present before registering — test fixture polluted`);

    await page.locator(".color-swatch--new").click();
    await page.locator('dialog[data-color-picker-target="dialog"] select[name="cor_material[nome]"]').selectOption(colorName);
    await page.click('button[data-action="click->color-picker#submitNew"]');
    await page.waitForURL("**/movimentos/new", { timeout: 10000 });
    await page.waitForSelector(".color-swatch-grid", { timeout: 10000 });

    const swatch = page.locator(`.color-swatch[title="${colorName}"]`);
    await swatch.waitFor({ timeout: 5000 });
    await swatch.click();
    const nameLabel = await page.locator('[data-color-picker-target="name"]').textContent();
    if (nameLabel.trim() !== colorName) throw new Error(`Expected selected color name "${colorName}", got "${nameLabel.trim()}"`);
  });
});
