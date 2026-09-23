const path = require("path");
const fs = require("fs");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { testImagesDir } = require("./support/fixtures");

runSpec("Arquivos E2E: corte comparison", async ({ page, test }) => {
  // ── Corte Comparison on Arte Show Page ──

  await test("Corte Comparison: arte with tamanho shows corte sizes table", async () => {
    const dxfPath = path.join(testImagesDir, "29-30.dxf");
    if (!fs.existsSync(dxfPath)) throw new Error("DXF not found");
    const { execSync } = require("child_process");

    // Upload the DXF and arte TIF
    const artePath = path.join(__dirname, `e2e-compare-arte-${Date.now()}.tif`);
    execSync(`convert -size 30x30 xc:blue 'TIFF:${artePath}'`);

    let dxfUuid = null;
    let arteUuid = null;

    try {
      await page.goto(BASE_URL);

      // Upload both files
      await uploadFileAndWait(page, [dxfPath, artePath]);

      const arteBaseName = path.basename(artePath, ".tif");

      // The upload controller sends files sequentially (DXF first, then arte);
      // uploadFileAndWait already waited for both POSTs, so this is a sanity
      // check that the arte card made it into the reloaded gallery.
      const arteCard = page.locator(".stamp-card").filter({ hasText: arteBaseName }).first();
      await arteCard.waitFor({ timeout: 30000 });

      // Organize the 29-30 DXF
      const dxfCard = page.locator(".stamp-card").filter({ hasText: "29-30" }).first();
      await dxfCard.locator("a").first().click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      // Create molde + peca via API
      const csrf = await page.evaluate(() =>
        document.querySelector("meta[name='csrf-token']")?.content || ""
      );

      await page.evaluate(async (token) => {
        await fetch("/pecas", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, "peca[nome]": "CorteCompPiece" })
        });
        const pecaRes = await fetch("/pecas/search?q=CorteCompPiece");
        const pecas = await pecaRes.json();
        const pecaId = pecas[0]?.id;

        await fetch("/moldes", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, "molde[nome]": "CorteCompMold", "molde[peca_ids][]": pecaId || "" })
        });
      }, csrf);

      // Reload so the <select> options include the newly created molde/peca
      await page.reload();
      await page.waitForSelector("h2", { timeout: 10000 });

      // If the DXF was already organized by a prior test, the <select> is hidden
      // in an edit-toggle form span. Force it visible for this interaction.
      await page.evaluate(() => {
        const forms = document.querySelectorAll('[data-edit-toggle-target="form"]');
        forms.forEach(el => el.style.display = "");
        const displays = document.querySelectorAll('[data-edit-toggle-target="display"]');
        displays.forEach(el => el.style.display = "none");
      });

      await page.selectOption('select[name="molde_id"]', { label: "CorteCompMold" });
      await page.selectOption('select[name="peca_id"]', { label: "CorteCompPiece" });

      const saveBtn = await page.$('.mold-organization-form button[type="submit"], .mold-organization-form input[type="submit"]');
      if (!saveBtn) throw new Error("Save button not found on mold organization form");
      await saveBtn.click();
      await page.waitForTimeout(1500);

      // Get the tamanho ID from the organization (read-only display rows)
      const tamanhos = await page.evaluate(() => {
        const rows = document.querySelectorAll(".tamanho-list--readonly .tamanho-row");
        return Array.from(rows).map(row => ({
          id: row.getAttribute("data-tamanho-id"),
          nome: (row.querySelector(".tamanho-nome")?.textContent || "").trim()
        }));
      });
      if (tamanhos.length === 0) throw new Error("No tamanhos after organization");
      const selectedTamanho = tamanhos[0];

      // Get the 29-30 DXF UUID
      dxfUuid = await page.evaluate(() => {
        const m = window.location.pathname.match(/\/arquivos\/([a-f0-9-]+)/);
        return m ? m[1] : null;
      });

      // Navigate to the arte
      await page.goto(BASE_URL);
      await page.waitForSelector(".stamp-card", { timeout: 10000 });
      await arteCard.waitFor({ timeout: 10000 });
      await arteCard.locator("a").first().click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      arteUuid = await page.evaluate(() => {
        const m = window.location.pathname.match(/\/arquivos\/([a-f0-9-]+)/);
        return m ? m[1] : null;
      });

      // Create a client and assign client + tamanho via API
      const csrf2 = await page.evaluate(() =>
        document.querySelector("meta[name='csrf-token']")?.content || ""
      );

      const apiOk = await page.evaluate(async ({ token, tamanhoId }) => {
        // Create client
        const cResp = await fetch("/clients", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, "client[name]": "CorteCompClient", "client[responsible]": "T" })
        });
        if (!cResp.ok) return { ok: false, step: "create client" };

        // Find it back
        const sResp = await fetch("/clients/search?q=CorteCompClient", { headers: { Accept: "application/json" } });
        const list = await sResp.json();
        const client = list.find(c => c.name === "CorteCompClient");
        if (!client) return { ok: false, step: "find client" };

        // Assign client to arte
        const arteUuid = window.location.pathname.match(/\/arquivos\/([a-f0-9-]+)/)?.[1];
        if (!arteUuid) return { ok: false, step: "uuid" };
        const cf = new URLSearchParams({ authenticity_token: token, client_id: client.id });
        const cr = await fetch(`/arquivos/${arteUuid}/update_client`, {
          method: "PATCH",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: cf.toString()
        });
        if (!cr.ok && cr.status !== 302) return { ok: false, step: "update client", status: cr.status };

        const tf = new URLSearchParams({ authenticity_token: token, tamanho_id: tamanhoId });
        const tr = await fetch(`/arquivos/${arteUuid}/update_tamanho`, {
          method: "PATCH",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: tf.toString()
        });
        if (!tr.ok && tr.status !== 302) return { ok: false, step: "update tamanho", status: tr.status };

        return { ok: true };
      }, { token: csrf2, tamanhoId: selectedTamanho.id });

      if (!apiOk.ok) {
        throw new Error(`Setup failed at ${apiOk.step}${apiOk.status ? ": " + apiOk.status : ""}`);
      }

      // Reload to render the comparison
      await page.reload();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      const body = await page.textContent("body");

      if (!body.includes("Comparison with Corte")) {
        throw new Error("Comparison with Corte section not found");
      }
      if (!body.includes("29-30")) {
        throw new Error("Corte name '29-30' not found in comparison");
      }
      if (!body.includes(selectedTamanho.nome)) {
        throw new Error(`Tamanho "${selectedTamanho.nome}" not found in comparison table`);
      }
      const badge = await page.$(".badge-selected");
      if (!badge) throw new Error("Selected size badge not found");
    } finally {
      await page.evaluate(async ({ dxfUuid, arteUuid }) => {
        // Find IDs via search
        let clientId, moldeId, pecaId;
        try {
          const cr = await fetch("/clients/search?q=CorteCompClient");
          const clients = await cr.json();
          const c = clients.find(x => x.name === "CorteCompClient");
          if (c) clientId = c.id;
        } catch (_) {}
        try {
          const mr = await fetch("/moldes/search?q=CorteCompMold");
          const moldes = await mr.json();
          const m = moldes.find(x => x.name === "CorteCompMold");
          if (m) moldeId = m.id;
        } catch (_) {}
        try {
          const pr = await fetch("/pecas/search?q=CorteCompPiece");
          const pecas = await pr.json();
          const p = pecas.find(x => x.name === "CorteCompPiece");
          if (p) pecaId = p.id;
        } catch (_) {}
        // Delete in reverse dependency order
        try { if (pecaId) await fetch(`/pecas/${pecaId}`, { method: "DELETE" }); } catch (_) {}
        try { if (moldeId) await fetch(`/moldes/${moldeId}`, { method: "DELETE" }); } catch (_) {}
        try { if (dxfUuid) await fetch(`/arquivos/${dxfUuid}`, { method: "DELETE", redirect: "manual" }); } catch (_) {}
        try { if (arteUuid) await fetch(`/arquivos/${arteUuid}`, { method: "DELETE", redirect: "manual" }); } catch (_) {}
        try { if (clientId) await fetch(`/clients/${clientId}`, { method: "DELETE" }); } catch (_) {}
      }, { dxfUuid, arteUuid }).catch(() => {});
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
    }
  });
});
