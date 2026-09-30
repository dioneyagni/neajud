// The "Unlink model" button on an arte (28/09/2026): like the client's, it
// clears the modelo — and the tamanho/molde that came with it — so the choice
// starts over (changing 21-24 → 28-29 used to keep 21-24's size).
const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Arquivos E2E: unlink model", async ({ page, test }) => {
  const UNIQ = `U${Date.now()}`;
  const arteName = `e2e-unlink-${UNIQ}`;
  let arteUuid = null;

  await test("Setup: an arte with a client and a model", async () => {
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
      await post("/modelos", { "modelo[nome]": `Unlink Modelo ${uniq}`, "modelo[client_uuid]": client.id });
      const modelo = (await (await fetch(`/modelos/search?q=${encodeURIComponent(`Unlink Modelo ${uniq}`)}`)).json())[0];
      const c = await post(`/arquivos/${uuid}/update_client`, { _method: "patch", client_uuid: client.id });
      const m = await post(`/arquivos/${uuid}/update_modelo`, { _method: "patch", modelo_uuid: modelo.id });
      return c.ok && m.ok;
    }, { uuid: arteUuid, uniq: UNIQ });
    if (!ok) throw new Error("Could not link client and model to the arte");
  });

  await test("Unlink model clears the model; the size section hides again", async () => {
    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    const secao = page.locator("#modelo-field-section");
    if (!(await secao.textContent()).includes(`Unlink Modelo ${UNIQ}`)) throw new Error("Model not shown before unlinking");
    await secao.locator('button[title="Unlink model"]').click();
    await waitForText(page, "No model linked");
    if (!(await page.locator("#size-selection-section").isHidden())) throw new Error("Size Selection still shown without a model");
    await page.reload();
    if (!(await page.locator("#modelo-field-section").textContent()).includes("No model linked")) throw new Error("Unlink didn't persist");
  });
});
