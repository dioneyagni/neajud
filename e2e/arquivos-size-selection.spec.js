const path = require("path");
const fs = require("fs");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { modeloOficial } = require("./support/catalogo");
const { waitForQueuedTask } = require("./support/wait");

runSpec("Arquivos E2E: size selection", async ({ page, test }) => {
  // ── Size Selection (Arte arquivos) ──

  await test("Size Selection: in DOM but hidden when arte has client and no molde", async () => {
    const arteSizePath = path.join(__dirname, `e2e-size-arte-${Date.now()}.tif`);
    if (!fs.existsSync(arteSizePath)) {
      const { execSync } = require("child_process");
      execSync(`convert -size 30x30 xc:blue 'TIFF:${arteSizePath}'`);
    }

    const arteBaseName = path.basename(arteSizePath, ".tif");

    let arteUuid = null;
    let clientId = null;

    try {
      await page.goto(BASE_URL);
      await page.waitForSelector('input[type="file"]', { timeout: 5000 });

      await uploadFileAndWait(page, arteSizePath);

      const sizeCard = page.locator(".stamp-card").filter({ hasText: arteBaseName }).first();
      await sizeCard.waitFor({ state: "visible", timeout: 15000 });
      const sizeCardCount = await sizeCard.count();
      if (sizeCardCount === 0) throw new Error("Arte arquivo card not found");

      const sizeLink = sizeCard.locator("a").first();
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), sizeLink.click() ]);

      const csrf = await page.evaluate(() => {
        const meta = document.querySelector("meta[name='csrf-token']");
        return meta?.content || "";
      });

      arteUuid = await page.evaluate(() => window.location.pathname.split("/").pop());

      await page.evaluate(async (token) => {
        await fetch("/clients", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, "client[name]": "Size Test Client", "client[responsible]": "Tester" })
        });
      }, csrf);

      clientId = await page.evaluate(async () => {
        const r = await fetch("/clients/search?q=Size Test Client");
        const clients = await r.json();
        return clients[0] ? clients[0].id : null;
      });

      const clientAssigned = await page.evaluate(async ({ token, clientId }) => {
        const uuid = window.location.pathname.split("/").pop();
        const res = await fetch(`/arquivos/${uuid}/update_client`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, _method: "patch", client_uuid: clientId })
        });
        return res.ok;
      }, { token: csrf, clientId });

      if (!clientAssigned) throw new Error("Failed to assign client");

      await page.reload();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      // Must exist so update_molde's turbo stream has a target to replace
      const sectionInDOM = await page.evaluate(() => !!document.querySelector("#size-selection-section"));
      if (!sectionInDOM) throw new Error("Size Selection section should be in DOM (turbo stream target) for arte files");

      const visible = await page.locator("#size-selection-section").isVisible();
      if (visible) throw new Error("Size Selection should stay hidden until a molde is selected");
    } finally {
      await page.evaluate(async ({ clientId, arteUuid }) => {
        try { if (clientId) await fetch(`/clients/${clientId}`, { method: "DELETE" }); } catch (_) {}
        try { if (arteUuid) await fetch(`/arquivos/${arteUuid}`, { method: "DELETE", redirect: "manual" }); } catch (_) {}
      }, { clientId, arteUuid }).catch(() => {});
      if (fs.existsSync(arteSizePath)) fs.unlinkSync(arteSizePath);
    }
  });





  await test("Size Selection: appears after picking molde and shows the linked tamanho in mm", async () => {
    const artePath = path.join(__dirname, "e2e-comp-arte.tif");
    if (!fs.existsSync(artePath)) {
      const { execSync } = require("child_process");
      execSync(`convert -size 30x30 xc:purple 'TIFF:${artePath}'`);
    }

    const orgPath = path.join(__dirname, "e2e-comp-org.tif");
    if (!fs.existsSync(orgPath)) {
      const { execSync } = require("child_process");
      execSync(`convert -size 20x20 xc:orange 'TIFF:${orgPath}'`);
    }

    let arteUuid = null;
    let orgUuid = null;
    let clientName = null;
    let pecaId = null;
    let modeloId = null;
    let moldeId = null;

    try {
      // ── Upload arte arquivo ──
      await page.goto(BASE_URL);
      await page.waitForSelector('input[type="file"]', { timeout: 5000 });
      await uploadFileAndWait(page, artePath);

      // Go to arte arquivo show page
      const arteCard = page.locator(".stamp-card").filter({ hasText: "e2e-comp-arte" }).first();
      await arteCard.waitFor({ timeout: 10000 });
      // Wait for the arquivo page itself: the gallery also has an h2 (headed
      // run 05/10/2026 read the gallery and found no #size-selection-section).
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), arteCard.locator("a").first().click() ]);

      arteUuid = await page.evaluate(() => window.location.pathname.split("/").pop());

      const csrf = await page.evaluate(() => {
        const meta = document.querySelector("meta[name='csrf-token']");
        return meta?.content || "";
      });

      // ── Create client ──
      clientName = "Comp Test Client " + Date.now();
      await page.evaluate(async ({ token, name }) => {
        await fetch("/clients", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, "client[name]": name, "client[responsible]": "Tester" })
        });
      }, { token: csrf, name: clientName });

      // ── Assign client via UI (combobox + turbo stream) ──
      const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
      await clientEditBtn.click();
      await page.waitForTimeout(300);

      const comboboxInput = await page.$(".combobox-input");
      if (!comboboxInput) throw new Error("Combobox input not found");
      await comboboxInput.focus();
      await comboboxInput.fill(clientName);
      await page.waitForTimeout(800);

      const option = page.locator(".combobox-option").filter({ hasText: clientName }).first();
      await option.waitFor({ timeout: 5000 });
      await option.click();
      await page.waitForTimeout(1500);

      // ── Create peca, modelo, molde ──
      const chain = await page.evaluate(async ({ token, clientName }) => {
        await fetch("/pecas", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, "peca[nome]": "Comp Peca" })
        });
        const pecaRes = await fetch("/pecas/search?q=Comp Peca");
        const pecas = await pecaRes.json();
        if (!pecas[0]) return null;

        // Etapa 1.1 (3/5): the official modelo "Calce Fácil" (no other spec uses it).
        const modeloRes = await fetch("/modelos/search?q=" + encodeURIComponent("Calce Fácil"));
        const modelos = (await modeloRes.json()).filter((m) => m.nome === "Calce Fácil");
        if (!modelos[0]) return null;

        const clientRes = await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`);
        const clients = await clientRes.json();
        if (!clients[0]) return null;

        await fetch("/moldes", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            authenticity_token: token,
            "molde[sufixo]": "Comp Molde",
            "molde[client_uuid]": clients[0].id,
            "molde[modelo_uuid]": modelos[0].id
          })
        });

        return { modeloId: modelos[0].id, pecaId: pecas[0].id };
      }, { token: csrf, clientName });
      if (!chain) throw new Error("Failed to create peca/modelo/molde chain");
      modeloId = chain.modeloId;
      pecaId = chain.pecaId;

      // ── Assign molde via combobox ──
      const modelEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Mold" }).locator(".btn-edit").first();
      await modelEditBtn.click();
      await page.waitForTimeout(300);

      const modelInput = await page.$(".stamp-detail-section[id='molde-field-section'] .combobox-input");
      if (!modelInput) throw new Error("Model combobox input not found");
      await modelInput.focus();
      await modelInput.fill("Comp Molde");
      await page.waitForTimeout(800);

      const moldeption = page.locator(".combobox-option").filter({ hasText: "Comp Molde" }).first();
      await moldeption.waitFor({ timeout: 5000 });
      await moldeption.click();
      await page.waitForTimeout(1500);

      // Regression (019535b): turbo stream must reveal the section without reload
      const sizeSectionAfterMolde = page.locator("#size-selection-section");
      await sizeSectionAfterMolde.waitFor({ state: "visible", timeout: 5000 });

      // Etapa 0.6: the tamanho search runs in the queue; "Procurando tamanho…"
      // must go away by itself (broadcast refresh or the polling safety net).
      await page.waitForFunction(() => !document.querySelector(".busca-tamanho"), null, { timeout: 60000 })
        .catch(() => { throw new Error('"Procurando tamanho…" still shown after 60s'); });

      // ── Create organized arquivo and organize it ──
      await page.goto(BASE_URL);
      await page.waitForSelector('input[type="file"]', { timeout: 5000 });
      await uploadFileAndWait(page, orgPath);

      const orgCard = page.locator(".stamp-card").filter({ hasText: "e2e-comp-org" }).first();
      await orgCard.waitFor({ timeout: 10000 });
      // Wait for the arquivo page itself: the gallery also has an h2 (headed
      // run 05/10/2026 read the gallery and found no #size-selection-section).
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), orgCard.locator("a").first().click() ]);

      orgUuid = await page.evaluate(() => window.location.pathname.split("/").pop());

      const orgCsrf = await page.evaluate(() => {
        const meta = document.querySelector("meta[name='csrf-token']");
        return meta?.content || "";
      });

      const orgClientSet = await page.evaluate(async ({ token, clientName }) => {
        const r = await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`);
        const clients = await r.json();
        if (!clients[0]) return false;
        const uuid = window.location.pathname.split("/").pop();
        const res = await fetch(`/arquivos/${uuid}/update_client`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, _method: "patch", client_uuid: clients[0].id })
        });
        return res.ok;
      }, { token: orgCsrf, clientName });
      if (!orgClientSet) throw new Error("Failed to assign client to organized arquivo");

      // Organize the arquivo — create tamanho "99"
      const organized = await page.evaluate(async ({ token, chain }) => {
        const uuid = window.location.pathname.split("/").pop();
        const body = new URLSearchParams();
        body.append("authenticity_token", token);
        body.append("_method", "patch");
        body.append("modelo_uuid", chain.modeloId);
        body.append("peca_uuid", chain.pecaId);
        body.append("tamanhos[0][nome]", "99");
        body.append("tamanhos[0][width_mm]", "150");
        body.append("tamanhos[0][height_mm]", "250");
        body.append("tamanhos[0][area_mm2]", "8000");
        const r = await fetch(`/arquivos/${uuid}/organize`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body
        });
        return r.ok;
      }, { token: orgCsrf, chain });
      if (!organized) throw new Error("Failed to organize arquivo");

      // ── Navigate to arte show page and set tamanho via API ──
      await page.goto(BASE_URL);
      await page.waitForTimeout(500);
      const arteCard2 = page.locator(".stamp-card").filter({ hasText: "e2e-comp-arte" }).first();
      await arteCard2.waitFor({ timeout: 10000 });
      // Wait for the arquivo page itself: the gallery also has an h2 (headed
      // run 05/10/2026 read the gallery and found no #size-selection-section).
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), arteCard2.locator("a").first().click() ]);

      // Find the organized corte's tamanho through the arte's molde — the same
      // query Size Selection makes (the molde's cortes, 01/10/2026).
      const tamanhoId = await page.evaluate(async ({ pecaId }) => {
        const moldeUuid = document.querySelector("#size-selection-section").dataset.sizeCascadeMoldeUuidValue;
        const r = await fetch(`/tamanhos/for_cascade?molde_uuid=${moldeUuid}&peca_uuid=${pecaId}`);
        const all = await r.json();
        const found = all.find(t => t.nome === "99");
        return found ? found.id : null;
      }, { pecaId });

      if (!tamanhoId) throw new Error("Tamanho '99' not found via for_cascade API");

      // Set tamanho via API
      const setResult = await page.evaluate(async ({ token, tamanhoId }) => {
        const uuid = window.location.pathname.split("/").pop();
        const body = new URLSearchParams({ authenticity_token: token, _method: "patch", tamanho_uuid: tamanhoId });
        const r = await fetch(`/arquivos/${uuid}/update_tamanho`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body
        });
        return r.ok || r.status === 302;
      }, { token: csrf, tamanhoId });
      if (!setResult) throw new Error("Failed to set tamanho via API");

      // ── Reload to see Comparison with Corte ──
      await page.reload();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      // Verify Size Selection shows the linked tamanho with its dimensions
      const sizeSection = page.locator("#size-selection-section");
      await sizeSection.waitFor({ state: "visible", timeout: 5000 });
      const sizeText = await sizeSection.textContent();
      if (!sizeText.includes("99")) throw new Error(`Size Selection should show tamanho '99', got: "${sizeText.trim()}"`);
      if (!sizeText.includes("150.0×250.0 mm")) throw new Error(`Size Selection should show '150.0×250.0 mm', got: "${sizeText.trim()}"`);

      // Edit → cascade Piece → Size lists the tamanho with dimensions
      await sizeSection.locator(".btn-edit").click();
      await page.locator("#cascade_peca option", { hasText: "Comp Peca" }).waitFor({ state: "attached", timeout: 5000 });
      await page.selectOption("#cascade_peca", { label: "Comp Peca" });
      const sizeOption = page.locator("#cascade_tamanho option", { hasText: "99 (150.0×250.0 mm)" });
      await sizeOption.waitFor({ state: "attached", timeout: 5000 }).catch(async () => {
        const got = await page.locator("#cascade_tamanho option").allTextContents();
        throw new Error(`Expected size option "99 (150.0×250.0 mm)", got: ${JSON.stringify(got)}`);
      });
      await page.selectOption("#cascade_tamanho", { label: "99 (150.0×250.0 mm)" });
      const saveDisabled = await sizeSection.locator("button[type='submit']").isDisabled();
      if (saveDisabled) throw new Error("Save button should be enabled after choosing a size");
      await sizeSection.locator(".btn-cancel").click();

      // Verify Comparison with Corte shows the correct tamanho
      const body = await page.textContent("body");
      if (!body.includes("Comparison with Corte")) throw new Error("Comparison with Corte section not found");
      if (!body.includes("99")) throw new Error("Tamanho '99' not found in comparison table");

      const badge = await page.$(".badge-selected");
      if (!badge) throw new Error("Selected size badge not found in comparison table");


    } finally {
      // Cleanup DB records
      await page.evaluate(async ({ pecaId, modeloId, clientName, arteUuid, orgUuid }) => {
        // Find molde and client IDs
        let moldeId = null;
        let clientId = null;
        try {
          const mr = await fetch("/moldes/search?q=Comp Molde");
          const moldes = await mr.json();
          if (moldes[0]) moldeId = moldes[0].id;
        } catch (_) {}
        try {
          const cr = await fetch("/clients/search?q=" + encodeURIComponent(clientName || ""));
          const clients = await cr.json();
          if (clients[0]) clientId = clients[0].id;
        } catch (_) {}
        // Delete in reverse dependency order
        try { if (moldeId) await fetch(`/moldes/${moldeId}`, { method: "DELETE" }); } catch (_) {}
        try { if (pecaId) await fetch(`/pecas/${pecaId}`, { method: "DELETE" }); } catch (_) {}
        try { if (orgUuid) await fetch(`/arquivos/${orgUuid}`, { method: "DELETE", redirect: "manual" }); } catch (_) {}
        try { if (arteUuid) await fetch(`/arquivos/${arteUuid}`, { method: "DELETE", redirect: "manual" }); } catch (_) {}
        try { if (clientId) await fetch(`/clients/${clientId}`, { method: "DELETE" }); } catch (_) {}
      }, { pecaId, modeloId, clientName, arteUuid, orgUuid }).catch(() => {});
      // Cleanup local files
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
      if (fs.existsSync(orgPath)) fs.unlinkSync(orgPath);
    }

  });

  // Regression (01/10/2026): a molde moved to the official "Tenis" while its
  // corte kept the old category; Size Selection filtered by category and
  // listed no piece, so the size couldn't be chosen. It lists the molde's
  // own cortes now.
  await test("Size Selection lists the molde's corte even when it carries another category", async () => {
    const UNIQ = `SC${Date.now()}`;
    const dxf = path.join(__dirname, `e2e-corte-sc-${UNIQ}.dxf`);
    const arte = path.join(__dirname, `e2e-arte-sc-${UNIQ}.tif`);
    fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "29-30.dxf"), dxf);
    require("child_process").execSync(`convert -size 40x40 xc:green 'TIFF:${arte}'`);
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, [ dxf, arte ]);
    } finally {
      for (const f of [ dxf, arte ]) if (fs.existsSync(f)) fs.unlinkSync(f);
    }
    const uuidDe = async (nome) => (await page.locator(".stamp-card").filter({ hasText: nome }).first().locator("a").first().getAttribute("href")).split("/").pop();
    const corteUuid = await uuidDe(`e2e-corte-sc-${UNIQ}`);
    const arteUuid = await uuidDe(`e2e-arte-sc-${UNIQ}`);
    const tenis = await modeloOficial(page, "Tenis");
    const jogging = await modeloOficial(page, "Jogging");
    const ok = await page.evaluate(async ({ UNIQ, corteUuid, arteUuid, tenis, jogging }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const post = (url, campos) => fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) });
      const achar = async (url, chave, valor) => (await (await fetch(url)).json()).find((r) => r[chave] === valor)?.id;
      await post("/clients", { "client[name]": `SC Client ${UNIQ}`, "client[responsible]": "T" });
      const client = await achar(`/clients/search?q=SC Client ${UNIQ}`, "name", `SC Client ${UNIQ}`);
      await post("/pecas", { "peca[nome]": `SC Peca ${UNIQ}` });
      const peca = await achar(`/pecas/search?q=SC Peca ${UNIQ}`, "nome", `SC Peca ${UNIQ}`);
      await post("/moldes", { "molde[sufixo]": `SC ${UNIQ}`, "molde[client_uuid]": client, "molde[modelo_uuid]": tenis.id });
      const molde = await achar(`/moldes/search?q=SC ${UNIQ}`, "sufixo", `SC ${UNIQ}`);
      const passos = [
        await post(`/arquivos/${corteUuid}/update_client`, { _method: "patch", client_uuid: client }),
        // The corte keeps another category ("Jogging") than its molde ("Tenis").
        await post(`/arquivos/${corteUuid}/organize`, { _method: "patch", modelo_uuid: jogging.id, peca_uuid: peca,
          "tamanhos[0][nome]": "29-30", "tamanhos[0][width_mm]": "150", "tamanhos[0][height_mm]": "250", "tamanhos[0][area_mm2]": "8000" }),
        await post(`/arquivos/${corteUuid}/add_molde`, { molde_uuid: molde }),
        await post(`/arquivos/${arteUuid}/update_client`, { _method: "patch", client_uuid: client }),
        await post(`/arquivos/${arteUuid}/update_molde`, { _method: "patch", molde_uuid: molde })
      ];
      return passos.every((r) => r.ok);
    }, { UNIQ, corteUuid, arteUuid, tenis, jogging });
    if (!ok) throw new Error("Setup failed");
    // The automatic size search runs in the queue and refreshes the page when
    // it ends; wait for it so the page doesn't reload under the test.
    await waitForQueuedTask(page, `/arquivos/${arteUuid}/busca_tamanho.json`);

    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    const secao = page.locator("#size-selection-section");
    if (await secao.locator(".btn-edit").count()) await secao.locator(".btn-edit").click();
    await secao.locator(`select[data-size-cascade-target="pecaSelect"] option`, { hasText: `SC Peca ${UNIQ}` }).waitFor({ state: "attached", timeout: 10000 });
    await secao.locator(`select[data-size-cascade-target="pecaSelect"]`).selectOption({ label: `SC Peca ${UNIQ}` });
    await secao.locator(`select[data-size-cascade-target="tamanhoSelect"] option`, { hasText: "29-30" }).waitFor({ state: "attached", timeout: 10000 });
  });
});
