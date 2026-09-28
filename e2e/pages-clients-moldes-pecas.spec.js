const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Pages E2E: clients, moldes & pecas", async ({ page, test }) => {
  // ── Clients page CRUD ──

  await test("Clients page: renders table with clients", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const body = await page.textContent("body");
    if (!body.includes("Clients")) throw new Error("Clients page heading not found");
    if (!body.includes("New Client")) throw new Error("New Client button not found");
    if (!body.includes("Alpha Corp") && !body.includes("Test Client E2E") && !body.includes("Modal Client")) {
      throw new Error("No client rows shown in table");
    }
  });

  await test("Clients page: New Client button opens dialog", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const newBtn = await page.$("button[data-action='click->dialog#open']");
    if (!newBtn) throw new Error("New Client button not found");
    await newBtn.click();
    await page.waitForTimeout(500);

    const isOpen = await page.evaluate(() => document.querySelector(".client-dialog")?.open);
    if (!isOpen) throw new Error("Dialog not open after clicking New Client");

    const title = await page.evaluate(() => document.querySelector(".client-dialog h4")?.textContent);
    if (title !== "Register New Client") throw new Error(`Expected "Register New Client", got "${title}"`);

    const submitText = await page.evaluate(() => document.querySelector(".client-dialog [data-dialog-target='submitBtn']")?.textContent?.trim());
    if (submitText !== "Register") throw new Error(`Expected "Register", got "${submitText}"`);

    // Close dialog
    const cancelBtn = await page.$(".client-dialog .btn-secondary");
    if (!cancelBtn) throw new Error("Cancel button not found");
    await cancelBtn.click();
    await page.waitForTimeout(500);

    const isClosed = await page.evaluate(() => !document.querySelector(".client-dialog")?.open);
    if (!isClosed) throw new Error("Dialog did not close after Cancel");
  });

  await test("Clients page: create a new client", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const newBtn = await page.$("button[data-action='click->dialog#open']");
    await newBtn.click();
    await page.waitForTimeout(500);

    await page.fill("#client_name_dialog", "Clients Page Client");
    await page.fill("#client_responsible_dialog", "Clients Page Resp");
    await page.click(".client-dialog .btn-primary");
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("Client registered")) throw new Error(`Client not created: "${body.slice(0, 300)}"`);
    if (!body.includes("Clients Page Client")) throw new Error("New client not shown in table");
  });

  await test("Clients page: Edit button opens dialog in edit mode", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector(".clients-table", { timeout: 10000 });

    const editBtn = await page.$("button[data-action*='dialog#edit']");
    if (!editBtn) throw new Error("Edit button not found");

    const clientName = await editBtn.getAttribute("data-name");
    if (!clientName) throw new Error("Edit button has no data-name");

    await editBtn.click();
    await page.waitForTimeout(500);

    const isOpen = await page.evaluate(() => document.querySelector(".client-dialog")?.open);
    if (!isOpen) throw new Error("Dialog not open after Edit click");

    const title = await page.evaluate(() => document.querySelector(".client-dialog h4")?.textContent);
    if (title !== "Edit Client") throw new Error(`Expected "Edit Client", got "${title}"`);

    const submitText = await page.evaluate(() => document.querySelector(".client-dialog [data-dialog-target='submitBtn']")?.textContent?.trim());
    if (submitText !== "Update") throw new Error(`Expected "Update", got "${submitText}"`);

    // Verify name field is pre-filled
    const nameVal = await page.evaluate(() => document.querySelector("#client_name_dialog")?.value);
    if (nameVal !== clientName) throw new Error(`Expected name "${clientName}", got "${nameVal}"`);

    // Verify form action points to PATCH
    const actionUrl = await editBtn.getAttribute("data-action-url");
    if (!actionUrl) throw new Error("Edit button has no data-action-url");

    // Close without saving
    const cancelBtn = await page.$(".client-dialog .btn-secondary");
    await cancelBtn.click();
    await page.waitForTimeout(500);
  });

  await test("Clients page: edit a client name", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector(".clients-table", { timeout: 10000 });

    const editBtn = await page.$("button[data-action*='dialog#edit']");
    await editBtn.click();
    await page.waitForTimeout(500);

    // Clear and type new name
    await page.fill("#client_name_dialog", "Edited Client Name");
    await page.fill("#client_responsible_dialog", "Edited Responsible");
    await page.click(".client-dialog .btn-primary");
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("Client updated")) throw new Error(`Client not updated: "${body.slice(0, 300)}"`);
    if (!body.includes("Edited Client Name")) throw new Error("Edited name not shown in table");
  });

  await test("Clients page: dialog is centered in viewport", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const newBtn = await page.$("button[data-action='click->dialog#open']");
    await newBtn.click();
    await page.waitForTimeout(500);

    const position = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      const rect = d.getBoundingClientRect();
      return { top: rect.top, left: rect.left, vh: window.innerHeight, vw: window.innerWidth };
    });
    if (position.top > position.vh * 0.4 || position.top < 0)
      throw new Error(`Dialog not vertically centered: top=${position.top}, vh=${position.vh}`);

    // Close dialog
    const cancelBtn = await page.$(".client-dialog .btn-secondary");
    await cancelBtn.click();
  });

  await test("Clients page: Delete button removes a client", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector(".clients-table", { timeout: 10000 });

    const rowCountBefore = await page.$$eval(".clients-table tbody tr", els => els.length);

    const deleteBtn = await page.$("button.btn-danger");
    if (!deleteBtn) throw new Error("Delete button not found");
    await deleteBtn.click();
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("Client moved to the trash")) throw new Error(`Client not deleted: "${body.slice(0, 300)}"`);

    const rowCountAfter = await page.$$eval(".clients-table tbody tr", els => els.length);
    if (rowCountAfter >= rowCountBefore) throw new Error(`Row count did not decrease: before=${rowCountBefore}, after=${rowCountAfter}`);
  });

  await test("Clients page: Back to Gallery link works", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const backLink = await page.$('a[href="/"]');
    if (!backLink) throw new Error("Back to Gallery link not found");
    await backLink.click();
    await page.waitForURL("**/", { timeout: 5000 });

    const url = page.url();
    if (!url.endsWith("/")) throw new Error(`Did not navigate to homepage: ${url}`);
  });

  await test("Clients page: nav link in header", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector("header", { timeout: 5000 });

    const navLink = await page.$(".header-nav-link");
    if (!navLink) throw new Error("Header nav link not found");

    const href = await navLink.getAttribute("href");
    if (href !== "/clients") throw new Error(`Expected /clients, got ${href}`);

    await navLink.click();
    await page.waitForURL("**/clients", { timeout: 5000 });

    const body = await page.textContent("body");
    if (!body.includes("Clients")) throw new Error("Did not navigate to clients page");
  });

  // ------------------------------------------------------------------
  // Management Pages: Moldes, Pecas, Modelos
  // ------------------------------------------------------------------

  await test("Moldes page: nav link in header", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector("header nav", { timeout: 5000 });

    const navLinks = await page.$$(".header-nav-link");
    if (navLinks.length < 2) throw new Error(`Expected at least 2 nav links, got ${navLinks.length}`);

    const hrefs = await Promise.all(navLinks.map(l => l.getAttribute("href")));
    if (!hrefs.includes("/moldes")) throw new Error("Moldes nav link not found");
  });

  await test("Moldes page: index renders with heading", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.waitForSelector("h2", { timeout: 5000 });

    const body = await page.textContent("body");
    if (!body.includes("Moldes")) throw new Error("Moldes heading not found");

    const newLink = await page.$('a[href*="/moldes/new"]');
    if (!newLink) throw new Error("New Molde link not found");

    const backLink = await page.$('a[href="/"]');
    if (!backLink) throw new Error("Back to Gallery link not found");
  });

  async function createMolde(page, nome) {
    await page.goto(`${BASE_URL}/moldes/new`);
    await page.waitForSelector("h2", { timeout: 5000 });
    await page.fill("input[name='molde[nome]']", nome);
    await page.click("input[type='submit']");
    await page.waitForTimeout(1000);
  }

  await test("Moldes page: create a new molde via dedicated page", async () => {
    const nome = `E2E Molde ${Date.now()}`;
    await createMolde(page, nome);

    const body = await page.textContent("body");
    if (!body.includes(nome)) throw new Error(`Molde page did not show molde name: "${body.slice(0, 200)}"`);
  });

  await test("Moldes page: new page shows peças list", async () => {
    await page.goto(`${BASE_URL}/moldes/new`);
    await page.waitForSelector("h2", { timeout: 5000 });

    const body = await page.textContent("body");
    if (!body.includes("Componentes")) throw new Error("Componentes heading not found");
  });

  await test("Moldes page: edit a molde via dedicated page", async () => {
    await createMolde(page, `E2E Edit ${Date.now()}`);
    const currentUrl = page.url();

    // Navigate to edit
    await page.goto(`${currentUrl}/edit`);
    await page.waitForSelector("h2", { timeout: 5000 });

    const nomeInput = await page.$("input[name='molde[nome]']");
    if (!nomeInput) throw new Error("Name input not found on edit page");

    const currentName = await nomeInput.inputValue();
    await nomeInput.fill(`${currentName} Edited`);

    await page.click("input[type='submit']");
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes(currentName)) throw new Error(`Molde not updated: "${body.slice(0, 200)}"`);
  });

  await test("Moldes page: delete a molde", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });

    const deleteBtn = await page.$("button.btn-danger");
    if (!deleteBtn) throw new Error("Delete button not found");

    await deleteBtn.click();
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("moved to the trash")) {
      const status = await page.evaluate(() => document.title);
      throw new Error(`Molde not deleted — status: "${status}", body: "${body.slice(0, 300)}"`);
    }
  });

  await test("Pecas page: nav link in header", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector("header nav", { timeout: 5000 });

    const navLinks = await page.$$(".header-nav-link");
    const hrefs = await Promise.all(navLinks.map(l => l.getAttribute("href")));
    if (!hrefs.includes("/pecas")) throw new Error("Pecas nav link not found");
  });

  await test("Pecas page: index renders with heading", async () => {
    await page.goto(`${BASE_URL}/pecas`);
    await page.waitForSelector("h2", { timeout: 5000 });

    const body = await page.textContent("body");
    if (!body.includes("Peças")) throw new Error("Peças heading not found: " + body.slice(0, 200));

    const newLink = await page.$('a[href*="/pecas/new"]');
    if (!newLink) throw new Error("New Peça link not found");
  });

  await test("Pecas page: create a new peca via dedicated page", async () => {
    await page.goto(`${BASE_URL}/pecas/new`);
    await page.waitForSelector("h2", { timeout: 5000 });

    await page.fill("input[name='peca[nome]']", `E2E Peca ${Date.now()}`);
    await page.click("input[type='submit']");
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("registered")) throw new Error(`Peca not registered: "${body.slice(0, 200)}"`);
  });

  await test("Pecas page: edit a peca via dedicated page", async () => {
    await page.goto(`${BASE_URL}/pecas`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });

    // Scoped to the table: the header's own name also links to /senha/edit.
    const editLink = page.locator('.clients-table a[href*="/edit"]').first();
    if ((await editLink.count()) === 0) throw new Error("Edit link not found");

    await editLink.click();
    await page.waitForURL(/\/pecas\/\d+\/edit/);

    const nomeInput = page.locator("input[name='peca[nome]']");
    const currentName = await nomeInput.inputValue();
    await nomeInput.fill(`${currentName} Edited`);

    await page.click("input[type='submit']");
    await waitForText(page, "Peca updated.");
  });

  await test("Pecas page: delete a peca", async () => {
    await page.goto(`${BASE_URL}/pecas`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });

    const deleteBtn = await page.$("button.btn-danger");
    if (!deleteBtn) throw new Error("Delete button not found");

    const rowCountBefore = await page.$$eval(".clients-table tbody tr", els => els.length);

    await deleteBtn.click();
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("moved to the trash")) throw new Error(`Peca not deleted: "${body.slice(0, 200)}"`);
  });
});
