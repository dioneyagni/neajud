const path = require("path");
const fs = require("fs");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");

runSpec("Arquivos E2E: unique corte", async ({ page, test }) => {
  await test("Unique Corte: rejects duplicate peca for same molde", async () => {
    const prefix = "UniqCorte";
    const clientName = `${prefix}Client`;
    const pecaName = `${prefix}Peca`;
    const moldeName = `${prefix}Molde`;
    const dxf1Path = path.join(__dirname, `${prefix}-one.dxf`);
    const dxf2Path = path.join(__dirname, `${prefix}-two.dxf`);
    let modeloId, pecaId, moldeId, uuid1, uuid2;

    const assignClient = (uuid, token) => page.evaluate(async ({ token, uuid, clientName }) => {
      const r = await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`);
      const clients = await r.json();
      const c = clients.find(x => x.name === clientName);
      if (!c) return "client_not_found";
      const res = await fetch(`/arquivos/${uuid}/update_client`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: token, _method: "patch", client_uuid: c.id })
      });
      return res.ok || res.status === 302 ? "ok" : "update_failed";
    }, { token, uuid, clientName });

    const organize = (uuid, token) => page.evaluate(async ({ token, uuid, modeloId, pecaId }) => {
      const body = new URLSearchParams();
      body.append("authenticity_token", token);
      body.append("_method", "patch");
      body.append("modelo_uuid", modeloId);
      body.append("peca_uuid", pecaId);
      const res = await fetch(`/arquivos/${uuid}/organize`, {
        method: "POST",
        redirect: "manual",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body
      });
      return res.status;
    }, { token, uuid, modeloId, pecaId });

    const uploadAndOpen = async (filePath) => {
      await page.goto(BASE_URL);
      await page.waitForSelector('input[type="file"]', { timeout: 5000 });
      await uploadFileAndWait(page, filePath);
      const displayName = path.basename(filePath).replace(/\.[^.]+$/, "");
      const card = page.locator(".stamp-card").filter({ hasText: displayName }).first();
      await card.locator("a").first().click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);
      return page.evaluate(() => window.location.pathname.split("/").pop());
    };

    try {
      // Create test DXF files (distinct names so cards are unambiguous)
      fs.writeFileSync(dxf1Path, "0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n");
      fs.writeFileSync(dxf2Path, "0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n");

      // ── Get CSRF token ──
      await page.goto(BASE_URL);
      await page.waitForSelector("h1", { timeout: 5000 });
      const csrfToken = await page.evaluate(() => {
        const meta = document.querySelector("meta[name='csrf-token']");
        return meta?.content || "";
      });

      // ── Create setup: client, modelo, peca, molde ──
      const setup = await page.evaluate(async ({ token, prefix }) => {
        // Create client
        const cBody = new URLSearchParams({ authenticity_token: token, "client[name]": `${prefix}Client`, "client[responsible]": "T" });
        await fetch("/clients", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: cBody });
        await new Promise(r => setTimeout(r, 200));
        const cr = await fetch(`/clients/search?q=${encodeURIComponent(`${prefix}Client`)}`);
        const clients = await cr.json();
        const client = clients.find(x => x.name === `${prefix}Client`);
        if (!client) return "client_not_found";

        // Create peca
        const pBody = new URLSearchParams({ authenticity_token: token, "peca[nome]": `${prefix}Peca` });
        await fetch("/pecas", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: pBody });
        await new Promise(r => setTimeout(r, 200));
        const pr = await fetch(`/pecas/search?q=${encodeURIComponent(`${prefix}Peca`)}`);
        const pecas = await pr.json();
        const peca = pecas.find(x => x.nome === `${prefix}Peca`);
        if (!peca) return "peca_not_found";

        // Etapa 1.1 (3/5): the official modelo "Slide" (no other spec uses it).
        const mr = await fetch("/modelos/search?q=Slide");
        const modelo = (await mr.json()).find(x => x.nome === "Slide");
        if (!modelo) return "modelo_not_found";

        // Create molde linked to client + modelo
        const modBody = new URLSearchParams({
          authenticity_token: token,
          "molde[sufixo]": `${prefix}Molde`,
          "molde[client_uuid]": client.id,
          "molde[modelo_uuid]": modelo.id
        });
        await fetch("/moldes", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: modBody });

        return { modeloId: modelo.id, pecaId: peca.id, clientId: client.id };
      }, { token: csrfToken, prefix });

      if (typeof setup === "string") throw new Error(`Setup failed at: ${setup}`);
      if (!setup) throw new Error("Setup returned null");
      modeloId = setup.modeloId;
      pecaId = setup.pecaId;

      // Get molde id
      moldeId = await page.evaluate(async ({ prefix }) => {
        const r = await fetch(`/moldes/search?q=${encodeURIComponent(`${prefix}Molde`)}`);
        const moldes = await r.json();
        const m = moldes.find(x => x.sufixo === `${prefix}Molde`);
        return m ? m.id : null;
      }, { prefix });
      if (!moldeId) throw new Error("Molde not found");

      // ── First DXF: organize + link molde ──
      uuid1 = await uploadAndOpen(dxf1Path);
      const csrf1 = await page.evaluate(() => document.querySelector("meta[name='csrf-token']")?.content || "");
      if (await assignClient(uuid1, csrf1) !== "ok") throw new Error("Failed to assign client to corte1");
      const orgStatus1 = await organize(uuid1, csrf1);
      if (orgStatus1 !== 200) throw new Error(`Failed to organize corte1, got ${orgStatus1}`);
      const added1 = await page.evaluate(async ({ token, uuid, moldeId }) => {
        const r = await fetch(`/arquivos/${uuid}/add_molde`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, molde_uuid: moldeId })
        });
        return r.status;
      }, { token: csrf1, uuid: uuid1, moldeId });
      if (added1 !== 200) throw new Error(`Failed to link molde to corte1, got ${added1}`);

      // ── Second DXF: organize then try to link same molde ──
      uuid2 = await uploadAndOpen(dxf2Path);
      const csrf2 = await page.evaluate(() => document.querySelector("meta[name='csrf-token']")?.content || "");
      if (await assignClient(uuid2, csrf2) !== "ok") throw new Error("Failed to assign client to corte2");
      const orgStatus2 = await organize(uuid2, csrf2);
      if (orgStatus2 !== 200) throw new Error(`Failed to organize corte2, got ${orgStatus2}`);

      // Confirm corte2 actually got the peca assigned
      const pecaSet = await page.evaluate(async ({ token, uuid, pecaId }) => {
        const r = await fetch(`/arquivos/${uuid}`);
        const html = await r.text();
        return html.includes(`data-original-value="${pecaId}"`) || html.includes(`>${pecaId}<`);
      }, { token: csrf2, uuid: uuid2, pecaId });
      if (!pecaSet) throw new Error("corte2 peca_id not set after organize");

      // Try to link same molde — should FAIL with alert via turbo_stream
      const modelAdded2 = await page.evaluate(async ({ token, uuid, moldeId }) => {
        const r = await fetch(`/arquivos/${uuid}/add_molde`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, molde_uuid: moldeId })
        });
        const text = await r.text();
        return { status: r.status, body: text };
      }, { token: csrf2, uuid: uuid2, moldeId });

      if (modelAdded2.status !== 200) {
        throw new Error(`Expected turbo_stream 200 from add_molde on conflict, got ${modelAdded2.status}`);
      }
      if (!modelAdded2.body.includes("já possui corte organizado")) {
        throw new Error(`Expected alert in turbo_stream response, got: ${modelAdded2.body.slice(0, 200)}`);
      }

      console.log("  ✓ Unique Corte: duplicate peca+molde correctly rejected");
    } finally {
      // Cleanup
      try { if (uuid2) await page.evaluate((u) => fetch(`/arquivos/${u}`, { method: "DELETE", redirect: "manual" }).catch(() => {}), uuid2); } catch (_) {}
      try { if (uuid1) await page.evaluate((u) => fetch(`/arquivos/${u}`, { method: "DELETE", redirect: "manual" }).catch(() => {}), uuid1); } catch (_) {}
      try { if (moldeId) await page.evaluate((id) => fetch(`/moldes/${id}`, { method: "DELETE" }).catch(() => {}), moldeId); } catch (_) {}
      try { if (pecaId) await page.evaluate((id) => fetch(`/pecas/${id}`, { method: "DELETE" }).catch(() => {}), pecaId); } catch (_) {}
      try { await page.evaluate((n) => fetch(`/clients/search?q=${encodeURIComponent(n)}`).then(r => r.json()).then(clients => { const c = clients.find(x => x.name === n); if (c) fetch(`/clients/${c.id}`, { method: "DELETE" }); }), clientName); } catch (_) {}
      if (fs.existsSync(dxf1Path)) fs.unlinkSync(dxf1Path);
      if (fs.existsSync(dxf2Path)) fs.unlinkSync(dxf2Path);
    }
  });

  await test("Unique Corte: organize form shows alert via turbo_stream on conflict", async () => {
    const prefix = "UniqCorteOrg";
    const clientName = `${prefix}Client`;
    const pecaName = `${prefix}Peca`;
    const moldeName = `${prefix}Molde`;
    const dxf1Path = path.join(__dirname, `${prefix}-one.dxf`);
    const dxf2Path = path.join(__dirname, `${prefix}-two.dxf`);
    let modeloId, pecaId, moldeId, uuid1, uuid2;

    const uploadAndOpen = async (filePath) => {
      await page.goto(BASE_URL);
      await page.waitForSelector('input[type="file"]', { timeout: 5000 });
      await uploadFileAndWait(page, filePath);
      const displayName = path.basename(filePath).replace(/\.[^.]+$/, "");
      const card = page.locator(".stamp-card").filter({ hasText: displayName }).first();
      await card.locator("a").first().click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);
      return page.evaluate(() => window.location.pathname.split("/").pop());
    };

    try {
      fs.writeFileSync(dxf1Path, "0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n");
      fs.writeFileSync(dxf2Path, "0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n");

      await page.goto(BASE_URL);
      await page.waitForSelector("h1", { timeout: 5000 });
      const csrfToken = await page.evaluate(() => document.querySelector("meta[name='csrf-token']")?.content || "");

      const setup = await page.evaluate(async ({ token, prefix }) => {
        const cBody = new URLSearchParams({ authenticity_token: token, "client[name]": `${prefix}Client`, "client[responsible]": "T" });
        await fetch("/clients", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: cBody });
        await new Promise(r => setTimeout(r, 200));
        const cr = await fetch(`/clients/search?q=${encodeURIComponent(`${prefix}Client`)}`);
        const clients = await cr.json();
        const client = clients.find(x => x.name === `${prefix}Client`);
        if (!client) return "client_not_found";

        const pBody = new URLSearchParams({ authenticity_token: token, "peca[nome]": `${prefix}Peca` });
        await fetch("/pecas", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: pBody });
        await new Promise(r => setTimeout(r, 200));
        const pr = await fetch(`/pecas/search?q=${encodeURIComponent(`${prefix}Peca`)}`);
        const pecas = await pr.json();
        const peca = pecas.find(x => x.nome === `${prefix}Peca`);
        if (!peca) return "peca_not_found";

        // Etapa 1.1 (3/5): the official modelo "Slide" (no other spec uses it).
        const mr = await fetch("/modelos/search?q=Slide");
        const modelo = (await mr.json()).find(x => x.nome === "Slide");
        if (!modelo) return "modelo_not_found";

        const modBody = new URLSearchParams({
          authenticity_token: token,
          "molde[sufixo]": `${prefix}Molde`,
          "molde[client_uuid]": client.id,
          "molde[modelo_uuid]": modelo.id
        });
        await fetch("/moldes", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: modBody });
        await new Promise(r => setTimeout(r, 200));

        return { modeloId: modelo.id, pecaId: peca.id, clientId: client.id };
      }, { token: csrfToken, prefix });

      if (typeof setup === "string") throw new Error(`Setup failed at: ${setup}`);
      modeloId = setup.modeloId;
      pecaId = setup.pecaId;
      moldeId = await page.evaluate(async ({ prefix }) => {
        const r = await fetch(`/moldes/search?q=${encodeURIComponent(`${prefix}Molde`)}`);
        const moldes = await r.json();
        const m = moldes.find(x => x.sufixo === `${prefix}Molde`);
        return m ? m.id : null;
      }, { prefix });
      if (!moldeId) throw new Error("Molde not found");

      // ── corte1: organize + link molde via UI form ──
      uuid1 = await uploadAndOpen(dxf1Path);
      const csrf1 = await page.evaluate(() => document.querySelector("meta[name='csrf-token']")?.content || "");

      // Assign client
      const clientAssigned = await page.evaluate(async ({ token, uuid, clientName }) => {
        const r = await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`);
        const clients = await r.json();
        const c = clients.find(x => x.name === clientName);
        if (!c) return "client_not_found";
        const res = await fetch(`/arquivos/${uuid}/update_client`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, _method: "patch", client_uuid: c.id })
        });
        return res.ok || res.status === 302 ? "ok" : "failed";
      }, { token: csrf1, uuid: uuid1, clientName });
      if (clientAssigned !== "ok") throw new Error("Failed to assign client to corte1");

      // Pick modelo + peca via UI form, submit organize
      await page.selectOption('select[name="modelo_uuid"]', String(modeloId));
      await page.waitForTimeout(300);
      await page.selectOption('select[name="peca_uuid"]', String(pecaId));
      await page.waitForTimeout(300);
      await page.click('.mold-organization-form button[type="submit"]');
      await page.waitForTimeout(1000);

      // Link molde via add_molde (no conflict expected — same peca+molde)
      const added1 = await page.evaluate(async ({ token, uuid, moldeId }) => {
        const r = await fetch(`/arquivos/${uuid}/add_molde`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, molde_uuid: moldeId })
        });
        return r.status;
      }, { token: csrf1, uuid: uuid1, moldeId });
      if (added1 !== 200) throw new Error(`add_molde corte1 failed: ${added1}`);

      // ── corte2: link molde FIRST, then try organize via UI form ──
      uuid2 = await uploadAndOpen(dxf2Path);
      const csrf2 = await page.evaluate(() => document.querySelector("meta[name='csrf-token']")?.content || "");

      const clientAssigned2 = await page.evaluate(async ({ token, uuid, clientName }) => {
        const r = await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`);
        const clients = await r.json();
        const c = clients.find(x => x.name === clientName);
        if (!c) return "client_not_found";
        const res = await fetch(`/arquivos/${uuid}/update_client`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, _method: "patch", client_uuid: c.id })
        });
        return res.ok || res.status === 302 ? "ok" : "failed";
      }, { token: csrf2, uuid: uuid2, clientName });
      if (clientAssigned2 !== "ok") throw new Error("Failed to assign client to corte2");

      // Link molde first (no peca yet → no conflict at add_molde)
      const added2 = await page.evaluate(async ({ token, uuid, moldeId }) => {
        const r = await fetch(`/arquivos/${uuid}/add_molde`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ authenticity_token: token, molde_uuid: moldeId })
        });
        return r.status;
      }, { token: csrf2, uuid: uuid2, moldeId });
      if (added2 !== 200) throw new Error(`add_molde corte2 failed: ${added2}`);

      // Reload to reflect linked molde, then submit organize with conflicting peca
      await page.reload();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);
      await page.selectOption('select[name="modelo_uuid"]', String(modeloId));
      await page.waitForTimeout(300);
      await page.selectOption('select[name="peca_uuid"]', String(pecaId));
      await page.waitForTimeout(300);
      await page.click('.mold-organization-form button[type="submit"]');

      // Wait for turbo_stream to render the alert inside #organize-flash
      await page.waitForFunction(() => {
        const el = document.getElementById("organize-flash");
        return el && el.textContent.includes("já possui um corte");
      }, { timeout: 5000 });

      // corte2 must NOT be organized
      const corte2Organized = await page.evaluate(async ({ uuid }) => {
        const r = await fetch(`/arquivos/${uuid}`);
        const html = await r.text();
        return /This DXF file is not organized yet/.test(html) === false
          && /mold-organization-alert/.test(html) === false;
      }, { uuid: uuid2 });
      if (corte2Organized) throw new Error("corte2 should NOT be organized after conflict");

      console.log("  ✓ Unique Corte: organize form shows alert on peca+molde conflict");
    } finally {
      try { if (uuid2) await page.evaluate((u) => fetch(`/arquivos/${u}`, { method: "DELETE", redirect: "manual" }).catch(() => {}), uuid2); } catch (_) {}
      try { if (uuid1) await page.evaluate((u) => fetch(`/arquivos/${u}`, { method: "DELETE", redirect: "manual" }).catch(() => {}), uuid1); } catch (_) {}
      try { if (moldeId) await page.evaluate((id) => fetch(`/moldes/${id}`, { method: "DELETE" }).catch(() => {}), moldeId); } catch (_) {}
      try { if (pecaId) await page.evaluate((id) => fetch(`/pecas/${id}`, { method: "DELETE" }).catch(() => {}), pecaId); } catch (_) {}
      try { await page.evaluate((n) => fetch(`/clients/search?q=${encodeURIComponent(n)}`).then(r => r.json()).then(clients => { const c = clients.find(x => x.name === n); if (c) fetch(`/clients/${c.id}`, { method: "DELETE" }); }), clientName); } catch (_) {}
      if (fs.existsSync(dxf1Path)) fs.unlinkSync(dxf1Path);
      if (fs.existsSync(dxf2Path)) fs.unlinkSync(dxf2Path);
    }
  });
});
