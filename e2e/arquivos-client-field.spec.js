const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Arquivos E2E: client field", async ({ page, test }) => {
  // ── Client field ──

  await test("Client field: search and display on show page", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    // Wait for the arquivo page itself: the gallery has an h2 too (CI flake, 01/10/2026).
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/, { timeout: 15000 }), arquivoLink.click() ]);
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Client")) throw new Error("Client section not found");

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");

    await input.focus();
    await page.waitForTimeout(500);

    const results = await page.$(".combobox-results--open");
    if (!results) throw new Error("Dropdown not opened on focus");

    const newOption = await page.$(".combobox-option-new");
    if (!newOption) throw new Error("Register new client option not found in dropdown");
  });

  await test("Client field: search JSON endpoint returns results", async () => {
    // Create a client directly via API
    const tokenRes = await page.goto(BASE_URL);
    const csrf = await page.evaluate(() => {
      const meta = document.querySelector("meta[name='csrf-token']");
      return meta?.content || "";
    });

    await page.evaluate(async (token) => {
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          authenticity_token: token,
          "client[name]": "Test Client E2E",
          "client[responsible]": "John E2E"
        })
      });
    }, csrf);

    // Now search for it
    const searchRes = await page.evaluate(async () => {
      const r = await fetch("/clients/search?q=Test Client");
      return r.json();
    });
    if (!Array.isArray(searchRes) || searchRes.length === 0) throw new Error("Search returned no results");
    if (searchRes[0].name !== "Test Client E2E") throw new Error(`Wrong client name: ${searchRes[0].name}`);
    if (searchRes[0].responsible !== "John E2E") throw new Error(`Wrong responsible: ${searchRes[0].responsible}`);
  });

  await test("Client field: select existing client saves to arquivo", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    // Wait for the arquivo page itself: the gallery has an h2 too (CI flake, 01/10/2026).
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/, { timeout: 15000 }), arquivoLink.click() ]);
    await page.waitForTimeout(500);

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");

    // Type to search and select
    await input.fill("Test Client E2E");
    await page.waitForTimeout(500);

    // Click the first option
    const option = await page.$(".combobox-option");
    if (!option) throw new Error("No combobox option found");
    await option.click();
    await page.waitForTimeout(1000);

    // Verify client name appears in display (Turbo Stream replaces section, no flash notice)
    await page.waitForFunction(() => {
      const display = document.querySelector(".client-name-display");
      return display && display.textContent.includes("Test Client E2E");
    }, { timeout: 5000 });

    // Reload to verify persistence
    await page.reload();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);
    const clientNameDisplay = await page.$(".client-name-display");
    if (!clientNameDisplay) throw new Error("Client name display not found after reload");
    const nameText = await clientNameDisplay.textContent();
    if (nameText !== "Test Client E2E") throw new Error(`Client not persisted: "${nameText}"`);
  });

  await test("Client field: Cancel button closes the dialog", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    // Wait for the arquivo page itself: the gallery has an h2 too (CI flake, 01/10/2026).
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/, { timeout: 15000 }), arquivoLink.click() ]);
    await page.waitForTimeout(500);

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    // Focus combobox to open dropdown
    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");
    await input.focus();
    await page.waitForTimeout(500);

    // Click "Register new client" option
    const newOption = await page.$(".combobox-option-new");
    if (!newOption) throw new Error("Register new client option not found");
    await newOption.click();
    await page.waitForTimeout(500);

    // Dialog should be visible
    const dialog = await page.$(".client-dialog");
    if (!dialog) throw new Error("Client dialog not found");

    const isOpen = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      return d && d.open;
    });
    if (!isOpen) throw new Error("Dialog not open");

    // Verify dialog is centered (not at top-left corner)
    const position = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      const rect = d.getBoundingClientRect();
      return { top: rect.top, left: rect.left, vh: window.innerHeight, vw: window.innerWidth };
    });
    if (position.top > position.vh * 0.4 || position.top < 0)
      throw new Error(`Dialog not vertically centered: top=${position.top}, vh=${position.vh}`);
    if (position.left > position.vw * 0.4 || position.left < 0)
      throw new Error(`Dialog not horizontally centered: left=${position.left}, vw=${position.vw}`);

    // Click Cancel button
    const cancelBtn = await page.$(".client-dialog .btn-secondary");
    if (!cancelBtn) throw new Error("Cancel button not found");
    await cancelBtn.click();
    await page.waitForTimeout(500);

    // Verify dialog is closed
    const isClosed = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      return !d || !d.open;
    });
    if (!isClosed) throw new Error("Dialog did not close after Cancel");
  });

  await test("Client field: register new client via modal creates and redirects", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    // Wait for the arquivo page itself: the gallery has an h2 too (CI flake, 01/10/2026).
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/, { timeout: 15000 }), arquivoLink.click() ]);
    await page.waitForTimeout(500);

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    // Focus combobox to open dropdown
    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");
    await input.focus();
    await page.waitForTimeout(500);

    // Click "Register new client" option
    const newOption = await page.$(".combobox-option-new");
    if (!newOption) throw new Error("Register new client option not found");
    await newOption.click();
    await page.waitForTimeout(500);

    // Dialog should be visible
    const dialog = await page.$(".client-dialog");
    if (!dialog) throw new Error("Client dialog not found");

    const isOpen = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      return d && d.open;
    });
    if (!isOpen) throw new Error("Dialog not open");

    // Verify dialog is centered (not at top-left corner)
    const position = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      const rect = d.getBoundingClientRect();
      return { top: rect.top, left: rect.left, vh: window.innerHeight, vw: window.innerWidth };
    });
    if (position.top > position.vh * 0.4 || position.top < 0)
      throw new Error(`Dialog not vertically centered: top=${position.top}, vh=${position.vh}`);
    if (position.left > position.vw * 0.4 || position.left < 0)
      throw new Error(`Dialog not horizontally centered: left=${position.left}, vw=${position.vw}`);

    // Fill form and submit
    await page.fill("#client_name_dialog", "Modal Client");
    await page.fill("#client_responsible_dialog", "Modal Resp");

    // Click Register button in dialog
    await page.click(".client-dialog .btn-primary");
    await page.waitForTimeout(1000);

    // Verify redirect back with notice
    const body = await page.textContent("body");
    if (!body.includes("Client registered")) throw new Error(`Notice not shown: "${body.slice(0, 200)}"`);

    // Verify client exists via search
    const searchRes = await page.evaluate(async () => {
      const r = await fetch("/clients/search?q=Modal Client");
      return r.json();
    });
    if (!searchRes.find(c => c.name === "Modal Client")) throw new Error("Modal Client not found in search");

    // Verify client was auto-assigned to the arquivo (stamp_uuid in dialog form)
    await page.reload();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);
    const clientNameDisplay = await page.$(".client-name-display");
    if (!clientNameDisplay) throw new Error("Client name display not found after reload");
    const displayName = await clientNameDisplay.textContent();
    if (displayName !== "Modal Client") throw new Error(`Client not auto-assigned to arquivo. Display value: "${displayName}"`);
  });

  await test("Client field: has edit toggle button on arquivo show page", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    // Wait for the arquivo page itself: the gallery has an h2 too (CI flake, 01/10/2026).
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/, { timeout: 15000 }), arquivoLink.click() ]);
    await page.waitForTimeout(500);

    // Edit toggle button should be present on arquivo show page
    const editBtn = await page.$("button[data-action*='edit-toggle#edit']");
    if (!editBtn) throw new Error("Edit toggle button not found in Client section");

    // "Manage Clients" link should be present
    const manageLink = await page.$('a[href="/clients"]');
    if (!manageLink) throw new Error("Manage Clients link not found");
  });

// Unlink is tested via RSpec request spec (E2E combobox submit is unreliable in sequence)

  await test("Client field: duplicate client name shows error", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    // Wait for the arquivo page itself: the gallery has an h2 too (CI flake, 01/10/2026).
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/, { timeout: 15000 }), arquivoLink.click() ]);
    await page.waitForTimeout(500);

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");
    await input.focus();
    await page.waitForTimeout(500);

    const newOption = await page.$(".combobox-option-new");
    if (!newOption) throw new Error("Register new client option not found");
    await newOption.click();
    await page.waitForTimeout(500);

    const dialog = await page.$(".client-dialog");
    if (!dialog) throw new Error("Client dialog not found");

    // Fill with existing name "Test Client E2E"
    await page.fill("#client_name_dialog", "Test Client E2E");
    await page.fill("#client_responsible_dialog", "Duplicate Test");
    await page.click(".client-dialog .btn-primary");
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("already exists")) throw new Error(`Duplicate name should show error: "${body.slice(0, 200)}"`);
  });
});
