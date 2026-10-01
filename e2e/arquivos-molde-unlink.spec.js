// The "Unlink mold" button (named "Unlink model" before Etapa 1.1, 2/5) on an arte (28/09/2026): like the client's, it
// clears the molde — and the tamanho/modelo that came with it — so the choice
// starts over (changing 21-24 → 28-29 used to keep 21-24's size).
const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Arquivos E2E: unlink mold", async ({ page, test }) => {
  const UNIQ = `U${Date.now()}`;
  const arteName = `e2e-unlink-${UNIQ}`;
  let arteUuid = null;

  await test("Setup: an arte with a client and a mold", async () => {
    const artePath = path.join(__dirname, `${arteName}.tif`);
    try {
      execSync(`convert -size 30x30 xc:teal 'TIFF:${artePath}'`);
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, artePath);
    } finally {
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
    }
    arteUuid = (await page.locator(`.stamp-card[data-filename="${arteName}"] a`).first().getAttribute("href")).split("/").pop();
    const ok = await page.evaluate(async ({ uuid, uniq }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const post = (url, fields) => fetch(url, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: token, ...fields }) });
      await post("/clients", { "client[name]": `Unlink Client ${uniq}`, "client[responsible]": "T" });
      const client = (await (await fetch(`/clients/search?q=${encodeURIComponent(`Unlink Client ${uniq}`)}`)).json())[0];
      // A molde needs a modelo for its code (Etapa 1.1, 4/5).
      const tenis = (await (await fetch("/modelos/search?q=Tenis")).json()).find((m) => m.nome === "Tenis");
      await post("/moldes", { "molde[sufixo]": `Unlink Molde ${uniq}`, "molde[client_uuid]": client.id, "molde[modelo_uuid]": tenis.id });
      const molde = (await (await fetch(`/moldes/search?q=${encodeURIComponent(`Unlink Molde ${uniq}`)}`)).json())[0];
      const c = await post(`/arquivos/${uuid}/update_client`, { _method: "patch", client_uuid: client.id });
      const m = await post(`/arquivos/${uuid}/update_molde`, { _method: "patch", molde_uuid: molde.id });
      return c.ok && m.ok;
    }, { uuid: arteUuid, uniq: UNIQ });
    if (!ok) throw new Error("Could not link client and mold to the arte");
  });

  await test("Unlink mold clears the mold; the size section hides again", async () => {
    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    const secao = page.locator("#molde-field-section");
    if (!(await secao.textContent()).includes(`Unlink Molde ${UNIQ}`)) throw new Error("Mold not shown before unlinking");
    await secao.locator('button[title="Unlink mold"]').click();
    await waitForText(page, "No mold linked");
    if (!(await page.locator("#size-selection-section").isHidden())) throw new Error("Size Selection still shown without a mold");
    await page.reload();
    if (!(await page.locator("#molde-field-section").textContent()).includes("No mold linked")) throw new Error("Unlink didn't persist");
  });

  // Regression (01/10/2026, pedido ed6a2aba): picking a client's molde on an
  // arte without client left it without one — and its pedido without client.
  await test("Picking a molde on an arte without client gives it the molde's client", async () => {
    const nome = `e2e-sem-cliente-${UNIQ}`;
    const caminho = path.join(__dirname, `${nome}.tif`);
    execSync(`convert -size 30x30 xc:blue 'TIFF:${caminho}'`);
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, caminho);
    } finally {
      if (fs.existsSync(caminho)) fs.unlinkSync(caminho);
    }
    const uuid = (await page.locator(`.stamp-card[data-filename="${nome}"] a`).first().getAttribute("href")).split("/").pop();
    const ok = await page.evaluate(async ({ uuid, uniq }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const molde = (await (await fetch(`/moldes/search?q=${encodeURIComponent(`Unlink Molde ${uniq}`)}`)).json())[0];
      const body = new URLSearchParams({ authenticity_token: token, _method: "patch", molde_uuid: molde.id });
      return (await fetch(`/arquivos/${uuid}/update_molde`, { method: "POST", body })).ok;
    }, { uuid, uniq: UNIQ });
    if (!ok) throw new Error("Could not pick the molde");
    await page.goto(`${BASE_URL}/arquivos/${uuid}`);
    await page.locator("#client-field-section .client-name-display").filter({ hasText: `Unlink Client ${UNIQ}` }).waitFor({ timeout: 5000 });
  });
});
