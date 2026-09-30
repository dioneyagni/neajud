const path = require("path");
const fs = require("fs");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForQueuedTask } = require("./support/wait");
const { uploadFileAndWait } = require("./support/upload");
const { testImagesDir } = require("./support/fixtures");

runSpec("Arquivos E2E: auto-detection", async ({ page, test }) => {
  // ── Auto-detection: update_molde triggers MoldMatchService ──

  await test("Auto-detection: update_molde triggers MoldMatchService and selects tamanho", async () => {
    const dxfSrc = path.join(testImagesDir, "29-30.dxf");
    if (!fs.existsSync(dxfSrc)) throw new Error("DXF not found");

    const { execSync } = require("child_process");
    const ts = Date.now();

    // Copy DXF to a unique temp name so we can find it reliably
    const dxfName = `auto-detect-${ts}.dxf`;
    const dxfPath = path.join(__dirname, dxfName);
    fs.copyFileSync(dxfSrc, dxfPath);

    // Arte TIF sized to match 29-30's sole tamanho (218.69×225.48mm at 300 DPI)
    const artePath = path.join(__dirname, `auto-detect-arte-${ts}.tif`);
    execSync(`convert -size 2583x2663 xc:white -units PixelsPerInch -density 300 -fill "#E8E8E8" -draw "roundrectangle 50,50 2533,2613 20,20" -define tiff:bits-per-sample=8 'TIFF:${artePath}'`);

    const displayName = path.basename(dxfName, ".dxf");
    const arteDisplay = path.basename(artePath, ".tif");
    let dxfUuid = null;
    let arteUuid = null;
    let modeloId = null;

    try {
      await page.goto(BASE_URL);

      // Upload both files
      await uploadFileAndWait(page, [dxfPath, artePath]);

      // ── Organize the DXF ──
      const dxfCard = page.locator(".stamp-card").filter({ hasText: displayName }).first();
      await dxfCard.locator("a").first().click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      const csrf = await page.evaluate(() =>
        document.querySelector("meta[name='csrf-token']")?.content || ""
      );

      // Create the peca via API; the modelo is the official "Bota" (Etapa 1.1,
      // 3/5), which no other spec uses, so MoldMatchService only sees this corte.
      await page.evaluate(async (token) => {
        await fetch("/pecas", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, "peca[nome]": "AutoDetectPiece" })
        });
      }, csrf);

      await page.reload();
      await page.waitForSelector("h2", { timeout: 10000 });

      await page.selectOption('select[name="modelo_uuid"]', { label: "Bota" });
      await page.selectOption('select[name="peca_uuid"]', { label: "AutoDetectPiece" });

      const saveBtn = await page.$('.mold-organization-form button[type="submit"], .mold-organization-form input[type="submit"]');
      if (!saveBtn) throw new Error("Save button not found on mold organization form");
      await saveBtn.click();
      await page.waitForTimeout(1500);

      // Get the modelo uuid from the organized DXF page
      dxfUuid = await page.evaluate(() => {
        const m = window.location.pathname.match(/\/arquivos\/([a-f0-9-]+)/);
        return m ? m[1] : null;
      });

      modeloId = await page.evaluate(async () => {
        const r = await fetch("/modelos/search?q=Bota");
        const list = await r.json();
        const m = list.find(x => x.nome === "Bota");
        return m ? m.id : null;
      });
      if (!modeloId) throw new Error("Could not find modelo after organization");

      // ── Navigate to the arte ──
      await page.goto(BASE_URL);
      await page.waitForSelector(".stamp-card", { timeout: 10000 });

      const arteCard = page.locator(".stamp-card").filter({ hasText: arteDisplay }).first();
      await arteCard.waitFor({ timeout: 10000 });
      await arteCard.locator("a").first().click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      arteUuid = await page.evaluate(() => {
        const m = window.location.pathname.match(/\/arquivos\/([a-f0-9-]+)/);
        return m ? m[1] : null;
      });

      // Wait for processing to complete
      const processedCheck = await page.evaluate(async (uuid) => {
        for (let i = 0; i < 30; i++) {
          const r = await fetch(`/arquivos/${uuid}`);
          const text = await r.text();
          if (text.includes("processed")) return true;
          await new Promise(r => setTimeout(r, 1000));
        }
        return false;
      }, arteUuid);
      if (!processedCheck) throw new Error("Arte processing did not complete within 30s");

      // Create client and assign to arte
      const csrf2 = await page.evaluate(() =>
        document.querySelector("meta[name='csrf-token']")?.content || ""
      );

      const apiOk = await page.evaluate(async ({ token, arteUuid, dxfUuid, modeloId }) => {
        // Create client
        const cResp = await fetch("/clients", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, "client[name]": "AutoDetectClient", "client[responsible]": "T" })
        });
        if (!cResp.ok) return { ok: false, step: "create client" };

        // Find it back
        const sResp = await fetch("/clients/search?q=AutoDetectClient", { headers: { Accept: "application/json" } });
        const list = await sResp.json();
        const client = list.find(c => c.name === "AutoDetectClient");
        if (!client) return { ok: false, step: "find client" };

        // Assign client to arte
        const cf = new URLSearchParams({ authenticity_token: token, client_uuid: client.id });
        const cr = await fetch(`/arquivos/${arteUuid}/update_client`, {
          method: "PATCH",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: cf.toString()
        });
        if (!cr.ok && cr.status !== 302) return { ok: false, step: "update client", status: cr.status };

        // The corte is the same client's, as in real data: the search never
        // takes another client's corte (Etapa 1.1, 3/5 — "Bota" is every
        // client's modelo).
        const cc = await fetch(`/arquivos/${dxfUuid}/update_client`, {
          method: "PATCH",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, client_uuid: client.id }).toString()
        });
        if (!cc.ok && cc.status !== 302) return { ok: false, step: "update corte client", status: cc.status };

        // Create a Molde linked to the organized modelo, under this client
        const mr = await fetch("/moldes", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            authenticity_token: token,
            "molde[nome]": "AutoDetectModel",
            "molde[client_uuid]": client.id,
            "molde[modelo_uuid]": modeloId
          })
        });
        if (!mr.ok) return { ok: false, step: "create molde", status: mr.status };

        // Find molde back
        const msResp = await fetch("/moldes/search?q=AutoDetectModel", { headers: { Accept: "application/json" } });
        const models = await msResp.json();
        const molde = models.find(m => m.nome === "AutoDetectModel");
        if (!molde) return { ok: false, step: "find molde" };

        // Assign molde to arte via update_molde (triggers MoldMatchService)
        const mf = new URLSearchParams({ authenticity_token: token, molde_uuid: molde.id });
        const mur = await fetch(`/arquivos/${arteUuid}/update_molde`, {
          method: "PATCH",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: mf.toString()
        });
        if (!mur.ok && mur.status !== 302) return { ok: false, step: "update molde", status: mur.status };

        return { ok: true };
      }, { token: csrf2, arteUuid, dxfUuid, modeloId });

      if (!apiOk.ok) {
        throw new Error(`Setup failed at ${apiOk.step}${apiOk.status ? ": " + apiOk.status : ""}`);
      }

      // Etapa 0.6: update_molde only queues the search (TamanhoAutoAssignJob).
      // Wait for it to end — the same endpoint the page polls — then reload.
      await waitForQueuedTask(page, `/arquivos/${arteUuid}/busca_tamanho.json`);
      await page.reload();
      await page.waitForSelector("h2", { timeout: 10000 });

      const body = await page.textContent("body");

      if (!body.includes("Comparison with Corte")) {
        throw new Error("Comparison with Corte section not found after molde assignment");
      }

      if (!body.includes(displayName)) {
        throw new Error(`Corte name '${displayName}' not found in comparison section`);
      }

      const badge = await page.$(".badge-selected");
      if (!badge) throw new Error("No selected size badge found — auto-detection did not set a tamanho");
    } finally {
      await page.evaluate(async ({ dxfUuid, arteUuid }) => {
        let clientId, pecaId, moldeId;
        try {
          const cr = await fetch("/clients/search?q=AutoDetectClient");
          const clients = await cr.json();
          const c = clients.find(x => x.name === "AutoDetectClient");
          if (c) clientId = c.id;
        } catch (_) {}
        try {
          const pr = await fetch("/pecas/search?q=AutoDetectPiece");
          const pecas = await pr.json();
          const p = pecas.find(x => x.nome === "AutoDetectPiece");
          if (p) pecaId = p.id;
        } catch (_) {}
        try {
          const mr2 = await fetch("/moldes/search?q=AutoDetectModel");
          const moldes = await mr2.json();
          const mo = moldes.find(x => x.nome === "AutoDetectModel");
          if (mo) moldeId = mo.id;
        } catch (_) {}
        try { if (moldeId) await fetch(`/moldes/${moldeId}`, { method: "DELETE" }); } catch (_) {}
        try { if (pecaId) await fetch(`/pecas/${pecaId}`, { method: "DELETE" }); } catch (_) {}
        try { if (dxfUuid) await fetch(`/arquivos/${dxfUuid}`, { method: "DELETE", redirect: "manual" }); } catch (_) {}
        try { if (arteUuid) await fetch(`/arquivos/${arteUuid}`, { method: "DELETE", redirect: "manual" }); } catch (_) {}
        try { if (clientId) await fetch(`/clients/${clientId}`, { method: "DELETE" }); } catch (_) {}
      }, { dxfUuid, arteUuid }).catch(() => {});
      if (fs.existsSync(dxfPath)) fs.unlinkSync(dxfPath);
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
    }
  });
});
