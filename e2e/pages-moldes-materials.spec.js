const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Pages E2E: moldes, show pages & materials", async ({ page, test }) => {
  await test("Moldes page: nav link in header", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector("header nav", { timeout: 5000 });

    const navLinks = await page.$$(".header-nav-link");
    const hrefs = await Promise.all(navLinks.map(l => l.getAttribute("href")));
    if (!hrefs.includes("/moldes")) throw new Error("Moldes nav link not found");
  });

  await test("Moldes page: index renders with heading", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.waitForSelector("h2", { timeout: 5000 });

    const body = await page.textContent("body");
    if (!body.includes("Moldes")) throw new Error("Moldes heading not found");

    const newBtn = await page.$("button.btn-primary");
    if (!newBtn) throw new Error("New Molde button not found");
  });

  await test("Moldes page: create a new molde via dialog", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.waitForSelector("h2", { timeout: 5000 });

    const newBtn = await page.$("button.btn-primary");
    await newBtn.click();
    await page.waitForTimeout(300);

    const dialog = await page.$("dialog[open]");
    if (!dialog) throw new Error("Dialog did not open");

    const title = await dialog.$eval("h4", el => el.textContent);
    if (title !== "Register New Molde") throw new Error(`Wrong dialog title: ${title}`);

    const nomeInput = await dialog.$("#molde_nome_dialog");
    await nomeInput.fill(`E2E Molde ${Date.now()}`);

    const clientSelect = await dialog.$("#molde_client_uuid_dialog");
    const clientOptions = await clientSelect.$$("option");
    if (clientOptions.length < 2) throw new Error(`Not enough client options: ${clientOptions.length}`);
    await clientSelect.selectOption({ index: 1 });

    const registerBtn = await dialog.$("button[type='submit']");
    await registerBtn.click();
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("registered")) throw new Error(`Molde not registered: "${body.slice(0, 200)}"`);
  });

  await test("Moldes page: edit a molde via dialog", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });

    const editBtn = await page.$("button[data-action='click->dialog#edit']");
    if (!editBtn) throw new Error("Edit button not found");

    await editBtn.click();
    await page.waitForTimeout(300);

    const dialog = await page.$("dialog[open]");
    if (!dialog) throw new Error("Edit dialog did not open");

    const nomeInput = await dialog.$("#molde_nome_dialog");
    const currentName = await nomeInput.inputValue();

    await nomeInput.fill(`${currentName} Edited`);

    const updateBtn = await dialog.$("button[type='submit']");
    await updateBtn.click();
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("updated")) throw new Error(`Molde not updated: "${body.slice(0, 200)}"`);
  });

  await test("Moldes page: delete a molde", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });

    const deleteBtn = await page.$("button.btn-danger");
    if (!deleteBtn) throw new Error("Delete button not found");

    const rowCountBefore = await page.$$eval(".clients-table tbody tr", els => els.length);

    await deleteBtn.click();
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("moved to the trash")) throw new Error(`Molde not deleted: "${body.slice(0, 200)}"`);
  });

  // ── Self-contained Show Page Tests ──
  // Each creates its own data so it can run independently of other sections.

  // Etapa 1.1 (3/5): modelos are the official list, so the show page uses one.
  await test("Modelos page: show page renders with details", async () => {
    const modeloName = "Tenis";
    const modelo = await page.evaluate(async (name) => {
      const r = await fetch(`/modelos/search?q=${encodeURIComponent(name)}`);
      const list = await r.json();
      return list.find((m) => m.nome === name) || null;
    }, modeloName);
    if (!modelo) throw new Error(`Modelo "${modeloName}" not found`);

    await page.goto(`${BASE_URL}/modelos/${modelo.id}`);
    await page.waitForSelector("h2", { timeout: 5000 });
    const body = await page.textContent("body");
    if (!body.includes(modeloName)) throw new Error(`Show page missing modelo name`);
    if (!body.includes("Details")) throw new Error("Show page missing Details section");
  });

  await test("Moldes page: show page renders with details", async () => {
    const token = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");

    const clientName = `Show Test Client ${Date.now()}`;
    const modeloName = "Tenis";
    const moldeName = `Show Test Molde ${Date.now()}`;

    const ids = await page.evaluate(async ({ csrf, clientName, modeloName, moldeName }) => {
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: csrf, "client[name]": clientName, "client[responsible]": "Tester" })
      });
      const clientRes = await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`);
      const clients = await clientRes.json();
      const modeloRes = await fetch(`/modelos/search?q=${encodeURIComponent(modeloName)}`);
      const modelos = (await modeloRes.json()).filter((m) => m.nome === modeloName);
      if (!clients[0] || !modelos[0]) return null;
      await fetch("/moldes", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: csrf, "molde[nome]": moldeName, "molde[client_uuid]": clients[0].id, "molde[modelo_uuid]": modelos[0].id })
      });
      const moldeRes = await fetch(`/moldes/search?q=${encodeURIComponent(moldeName)}`);
      const moldes = await moldeRes.json();
      return moldes[0]?.id || null;
    }, { csrf: token, clientName, modeloName, moldeName });
    if (!ids) throw new Error("Failed to create test data for moldes show");

    await page.goto(`${BASE_URL}/moldes/${ids}`);
    await page.waitForSelector("h2", { timeout: 5000 });
    const body = await page.textContent("body");
    if (!body.includes(moldeName)) throw new Error(`Show page missing molde name`);
    if (!body.includes("Details")) throw new Error("Show page missing Details section");
    if (!body.includes("Parts and cuts")) throw new Error("Show page missing the parts section");
  });

  await test("Clients page: show page renders with details", async () => {
    const token = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");
    const clientName = `Show Test Client ${Date.now()}`;

    const clientId = await page.evaluate(async ({ name, csrf }) => {
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: csrf, "client[name]": name, "client[responsible]": "Tester" })
      });
      const r = await fetch(`/clients/search?q=${encodeURIComponent(name)}`);
      const list = await r.json();
      return list[0]?.id || null;
    }, { name: clientName, csrf: token });
    if (!clientId) throw new Error("Failed to create test client");

    await page.goto(`${BASE_URL}/clients/${clientId}`);
    await page.waitForSelector("h2", { timeout: 5000 });
    const body = await page.textContent("body");
    if (!body.includes(clientName)) throw new Error(`Show page missing client name`);
    if (!body.includes("Details")) throw new Error("Show page missing Details section");
    if (!body.includes("Moldes")) throw new Error("Show page missing Moldes section");
    if (!body.includes("Arquivos")) throw new Error("Show page missing Arquivos section");
  });

  await test("Materials page: nav link in header", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector("header nav", { timeout: 5000 });

    const navLinks = await page.$$(".header-nav-link");
    const hrefs = await Promise.all(navLinks.map(l => l.getAttribute("href")));
    if (!hrefs.includes("/materiais")) throw new Error("Materials nav link not found");

    await page.goto(`${BASE_URL}/materiais`);
    await page.waitForSelector("h2", { timeout: 5000 });
    const body = await page.textContent("body");
    if (!body.includes("Materials Inventory")) throw new Error("Materials page heading not found");
    if (!body.includes("Register Movement")) throw new Error("Materials page missing link to registration");
  });

  await test("Materials page: client combobox shows multiple clients and selects correctly", async () => {
    await page.goto(`${BASE_URL}/materiais/new`);
    await page.waitForSelector("h2", { timeout: 5000 });

    const clientInput = page.locator(".client-field").first().locator(".combobox-input");
    await clientInput.focus();
    await page.waitForTimeout(800);

    // Check that multiple client options appear
    const clientOptions = page.locator(".combobox-option");
    const optionCount = await clientOptions.count();

    // We need at least 1 client option (the previous E2E tests create "Test Client E2E")
    // plus the "Register new" option = at least 2
    if (optionCount < 2) throw new Error(`Expected at least 2 combobox options, got ${optionCount}`);

    // Verify that clicking a client option sets the hidden input value
    const firstClientOption = clientOptions.first();
    const expectedId = await firstClientOption.getAttribute("data-id");
    await firstClientOption.click();
    const hiddenValue = await page.$eval("input[name='movimento_estoque[client_uuid]']", el => el.value);
    if (hiddenValue !== expectedId) throw new Error(`Hidden field value ${hiddenValue} does not match selected client id ${expectedId}`);
  });
});
