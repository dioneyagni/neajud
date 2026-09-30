const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");
const { modeloOficial } = require("./support/catalogo");

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

    // Etapa 1.1 (3/5): choosing the modelo fills the sizes with its produto's
    // grade (Calçado 18–46), whole grade by default.
    const dialog = page.locator("dialog[open]");
    await dialog.locator('select[name="molde[modelo_uuid]"]').selectOption({ label: "Tenis [TNS]" });
    const inicial = dialog.locator('select[name="molde[tamanho_inicial]"]');
    const final = dialog.locator('select[name="molde[tamanho_final]"]');
    const padrao = [ await inicial.inputValue(), await final.inputValue() ];
    if (padrao.join("-") !== "18-46") throw new Error(`Expected the whole grade 18-46 by default, got ${padrao.join("-")}`);
    await inicial.selectOption("24");
    await final.selectOption("34");

    await page.click('button[data-dialog-target="submitBtn"]:has-text("Register")');
    await waitForText(page, "Molde registered.");

    const linha = page.locator("tr", { hasText: `E2E Molde ${UNIQ}` });
    if (!(await linha.textContent()).includes("24–34")) {
      throw new Error(`New molde row lacks its sizes 24–34: ${(await linha.textContent()).replace(/\s+/g, " ")}`);
    }
  });

  // Banner has no grade (its measure comes with the no-cut work, Fase 2).
  await test("A modelo without grade offers no sizes", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    await page.click('button:has-text("New Molde")');
    const dialog = page.locator("dialog[open]");
    await dialog.locator('select[name="molde[modelo_uuid]"]').selectOption({ label: "Banner [BNN]" });
    const opcoes = await dialog.locator('select[name="molde[tamanho_inicial]"] option').allTextContents();
    if (opcoes.join("|") !== "—") throw new Error(`Expected only "—" for Banner, got ${opcoes.join("|")}`);
    await dialog.locator('button:has-text("Cancel")').click();
  });

  await test("Edit molde via dialog", async () => {
    await page.goto(`${BASE_URL}/moldes`);

    const editBtn = page.locator("tr", { hasText: `E2E Molde ${UNIQ}` }).locator('button:has-text("Edit")');
    await editBtn.click();

    const title = await page.locator('[data-dialog-target="dialogTitle"]').textContent();
    if (!title.includes("Edit")) throw new Error(`Dialog title not 'Edit', got "${title}"`);

    // The sizes come prefilled although their options depend on the modelo.
    const dialog = page.locator("dialog[open]");
    const tamanhos = [ await dialog.locator('select[name="molde[tamanho_inicial]"]').inputValue(),
                       await dialog.locator('select[name="molde[tamanho_final]"]').inputValue() ];
    if (tamanhos.join("-") !== "24-34") throw new Error(`Edit should prefill 24-34, got ${tamanhos.join("-")}`);

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

  // Etapa 1.1 (3/5): parts belong to the molde, chosen on its page.
  await test("Molde show: add parts, mark one as not cut, remove one, register a new piece", async () => {
    await page.goto(BASE_URL);
    const token = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");
    const nomes = { cliente: `Partes Client ${UNIQ}`, molde: `Partes Molde ${UNIQ}`, lateral: `Lateral ${UNIQ}`, lingua: `Lingua ${UNIQ}` };
    const tenis = await modeloOficial(page, "Tenis");

    const moldeId = await page.evaluate(async ({ csrf, nomes, modeloUuid }) => {
      const post = (url, campos) => fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: csrf, ...campos }) });
      await post("/clients", { "client[name]": nomes.cliente, "client[responsible]": "Tester" });
      await post("/pecas", { "peca[nome]": nomes.lateral });
      await post("/pecas", { "peca[nome]": nomes.lingua });
      const client = (await (await fetch(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).json())[0];
      await post("/moldes", { "molde[nome]": nomes.molde, "molde[client_uuid]": client.id, "molde[modelo_uuid]": modeloUuid });
      return (await (await fetch(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`)).json())[0]?.id || null;
    }, { csrf: token, nomes, modeloUuid: tenis.id });
    if (!moldeId) throw new Error("Failed to create the molde");

    await page.goto(`${BASE_URL}/moldes/${moldeId}`);
    await waitForText(page, "This molde has no parts yet.");

    for (const parte of [ nomes.lateral, nomes.lingua ]) {
      await page.selectOption("#peca_uuid_parte", { label: parte });
      await page.click('.molde-adicionar-parte button[type="submit"]');
      await waitForText(page, `Part "${parte}" added.`);
    }

    const lingua = page.locator(`.molde-peca-row[data-parte="${nomes.lingua}"]`);
    // The checkbox itself is hidden by the switch styling; click what users see.
    await lingua.locator(".toggle-slider").click();
    await lingua.locator(".molde-peca-status--not-needed").waitFor({ timeout: 10000 });

    await page.locator(`.molde-peca-row[data-parte="${nomes.lateral}"]`).locator('button:has-text("Remove")').click();
    await waitForText(page, `Part "${nomes.lateral}" removed.`);
    if (await page.locator(`.molde-peca-row[data-parte="${nomes.lateral}"]`).count() !== 0) throw new Error("Removed part still listed");

    const nova = `Reforco ${UNIQ}`;
    await page.click('a:has-text("+ Register new piece")');
    await page.fill("input[name='peca[nome]']", nova);
    await page.click("input[type='submit']");
    await waitForText(page, "Peça added to molde.");
    await page.locator(`.molde-peca-row[data-parte="${nova}"]`).waitFor({ timeout: 5000 });
  });
});
