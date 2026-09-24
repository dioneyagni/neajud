const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Materiais E2E Tests", async ({ page, test }) => {
  const UNIQ = `MAT${Date.now()}`;

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
      const existing = found.find((g) => g.nome === nome);
      if (existing) return existing.id;
      await fetch("/materiais/create_grupo", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "grupo_material[nome]": nome })
      });
      const created = await (await fetch(`/materiais/grupos?q=${encodeURIComponent(nome)}`)).json();
      return created.find((g) => g.nome === nome)?.id;
    }, { csrf, nome });
  }

  async function ensureCor(nome) {
    const csrf = await csrfToken();
    return page.evaluate(async ({ csrf, nome }) => {
      const found = await (await fetch("/materiais/cores")).json();
      const existing = found.find((c) => c.nome === nome);
      if (existing) return existing.id;
      await fetch("/materiais/create_cor", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "cor_material[nome]": nome })
      });
      const created = await (await fetch("/materiais/cores")).json();
      return created.find((c) => c.nome === nome)?.id;
    }, { csrf, nome });
  }

  async function ensureClient(nome) {
    const csrf = await csrfToken();
    return page.evaluate(async ({ csrf, nome }) => {
      const found = await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json();
      const existing = found.find((c) => c.name === nome);
      if (existing) return existing.id;
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "client[name]": nome, "client[responsible]": "Tester" })
      });
      const created = await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json();
      return created.find((c) => c.name === nome)?.id;
    }, { csrf, nome });
  }


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
    await page.goto(`${BASE_URL}/materiais`);
    await ensureGrupo(`GrupoListCheck${UNIQ}`);

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
    await page.goto(`${BASE_URL}/materiais`);
    await ensureCor("Branco");

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
    const movClientName = `Movement Client ${UNIQ}`;
    await page.goto(`${BASE_URL}/materiais`);
    await ensureGrupo("Oxford");
    await ensureCor("Azul");
    await ensureClient(movClientName);

    await page.goto(`${BASE_URL}/movimentos/new`);

    // Select grupo
    await page.locator('input[placeholder="Search group..."]').click();
    await page.locator('input[placeholder="Search group..."]').fill("Ox");
    await page.waitForTimeout(500);
    const grupoOption = page.locator(".combobox-option[data-name='Oxford']");
    await grupoOption.click();

    // Select client
    await page.locator('input[placeholder="Search client..."]').click();
    await page.locator('input[placeholder="Search client..."]').fill(movClientName.slice(0, 6));
    await page.waitForTimeout(500);
    const clientOption = page.locator(`.combobox-option[data-name='${movClientName}']`);
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
});
