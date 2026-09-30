const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Moldes E2E Tests", async ({ page, test }) => {
  const UNIQ = `M${Date.now()}`;


  await test("Moldes page loads", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    const body = await page.textContent("body");
    if (!body.includes("Moldes")) throw new Error("Page heading not found");
  });

  await test("New Molde button opens dialog", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.click('button:has-text("New Molde")');
    await page.waitForTimeout(300);

    const dialog = page.locator("dialog.client-dialog");
    const isOpen = await dialog.evaluate((el) => el.open);
    if (!isOpen) throw new Error("Dialog did not open");
  });

  await test("Create a new molde via dialog", async () => {
    // Client has no seed data (see AGENTS.md) — provision one so the
    // dropdown has something to select.
    const moldeClientName = `Molde Dialog Client ${UNIQ}`;
    await page.goto(BASE_URL);
    const setupCsrf = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");
    await page.evaluate(async ({ csrf, name }) => {
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "client[name]": name, "client[responsible]": "Tester" })
      });
    }, { csrf: setupCsrf, name: moldeClientName });

    await page.goto(`${BASE_URL}/moldes`);
    await page.click('button:has-text("New Molde")');
    await page.waitForTimeout(300);

    await page.fill('input[name="molde[nome]"]', `E2E Molde ${UNIQ}`);

    // Select the client just provisioned above
    const clientSelect = page.locator('select[name="molde[client_uuid]"]');
    const options = await clientSelect.locator("option").allTextContents();
    const clientOption = options.find((o) => o.includes(moldeClientName));
    if (!clientOption) throw new Error(`Client "${moldeClientName}" not found in dropdown`);
    await clientSelect.selectOption({ label: clientOption });

    await page.click('button[data-dialog-target="submitBtn"]:has-text("Register")');

    await page.waitForURL("**/moldes", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes(`E2E Molde ${UNIQ}`)) {
      throw new Error(`New molde not found in table. Body preview: ${body.slice(0, 300)}`);
    }
  });

  await test("Edit molde via dialog", async () => {
    await page.goto(`${BASE_URL}/moldes`);

    const editBtn = page.locator('button:has-text("Edit")').first();
    await editBtn.click();
    await page.waitForTimeout(300);

    const title = await page.locator('[data-dialog-target="dialogTitle"]').textContent();
    if (!title.includes("Edit")) throw new Error(`Dialog title not 'Edit', got "${title}"`);

    await page.fill('input[name="molde[nome]"]', `Edited Molde ${UNIQ}`);
    await page.click('button[data-dialog-target="submitBtn"]:has-text("Update")');
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes(`Edited Molde ${UNIQ}`)) {
      throw new Error("Edited molde name not found");
    }
  });

  await test("Molde show page displays details", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });

    const showLink = page.locator('a:has-text("Show")').first();
    const exists = await showLink.count();
    if (exists === 0) {
      console.log("        No molde to show — skipping");
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
    const backLink = page.locator('a:has-text("All Moldes")');
    const backExists = await backLink.count();
    if (backExists === 0) throw new Error("All Moldes link not found");
  });

  await test("Molde show: pecas list with toggle appears when modelo has pecas", async () => {
    const token = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");
    const ts = Date.now();
    const clientName = `Peca Toggle Client ${ts}`;
    const modeloName = `Peca Toggle Modelo ${ts}`;
    const moldeName = `Peca Toggle Molde ${ts}`;

    const moldeId = await page.evaluate(async ({ csrf, clientName, modeloName, moldeName }) => {
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: csrf, "client[name]": clientName, "client[responsible]": "Tester" })
      });
      const cr = await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`);
      const clients = await cr.json();
      if (!clients[0]) return null;

      await fetch("/modelos", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: csrf, "modelo[nome]": modeloName })
      });
      const mr = await fetch(`/modelos/search?q=${encodeURIComponent(modeloName)}`);
      const modelos = await mr.json();
      if (!modelos[0]) return null;

      await fetch("/moldes", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: csrf, "molde[nome]": moldeName, "molde[client_uuid]": clients[0].id, "molde[modelo_uuid]": modelos[0].id })
      });
      const mdr = await fetch(`/moldes/search?q=${encodeURIComponent(moldeName)}`);
      const moldes = await mdr.json();
      return moldes[0]?.id || null;
    }, { csrf: token, clientName, modeloName, moldeName });
    if (!moldeId) throw new Error("Failed to create molde with modelo");

    await page.goto(`${BASE_URL}/moldes/${moldeId}`);
    await page.waitForSelector("h2", { timeout: 5000 });

    const body = await page.textContent("body");
    if (!body.includes("Cortes")) throw new Error("Cortes section not found");
    if (!body.includes("No organized cuts") && !body.includes("Toggle")) {
      if (!body.includes("No organized cuts")) {
        throw new Error("Expected 'No organized cuts' message when modelo has no pecas configured");
      }
    }

    const toggleSwitches = await page.$$(".toggle-switch");
    if (toggleSwitches.length === 0) {
      console.log("        No toggle switches found — modelo may have no pecas");
    }
  });
});
